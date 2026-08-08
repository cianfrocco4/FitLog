//
//  EntitlementStore.swift
//  FitLog
//
//  Single source of truth for premium access via RevenueCat.
//

import Foundation
import Observation
import os

#if canImport(RevenueCat)
import RevenueCat
#endif

private let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.fitlog",
    category: "EntitlementStore"
)

/// UI-facing Premium status derived from RevenueCat entitlement (cancel ≠ immediate revoke).
struct PremiumAccessDetails: Equatable, Sendable {
    var isActive: Bool
    /// `false` when the user canceled (or promo/lifetime with no renewal).
    var willRenew: Bool
    var expirationDate: Date?
    var isPromotional: Bool

    static let inactive = PremiumAccessDetails(
        isActive: false,
        willRenew: false,
        expirationDate: nil,
        isPromotional: false
    )
}

@Observable @MainActor
final class EntitlementStore {
    private(set) var isPremium = false
    /// Richer status for Subscription settings (canceled-but-still-active, renewal date, etc.).
    private(set) var premiumDetails = PremiumAccessDetails.inactive
    private(set) var appUserID: String?
    private(set) var isConfigured = false
    private(set) var isLoadingOfferings = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var lastErrorMessage: String?
    /// Product ID → eligible for intro/trial. Missing key means unknown (do not claim free trial).
    private(set) var introEligibilityByProductID: [String: Bool] = [:]

#if canImport(RevenueCat)
    private(set) var offerings: Offerings?
    private(set) var customerInfo: CustomerInfo?
    private var customerInfoTask: Task<Void, Never>?
#endif

    init() {
#if DEBUG
        if FitLogUITestLaunch.isActive {
            isPremium = true
            appUserID = "uitest-user"
            isConfigured = true
        }
#endif
    }

    func configureIfNeeded() {
        guard !isConfigured else { return }
#if canImport(RevenueCat)
        guard let apiKey = RevenueCatConfig.apiKey else {
            log.notice("RevenueCat API key missing — premium features remain locked")
            // Do not call Purchases.shared before configure — that crashes.
            appUserID = nil
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isConfigured = true
        appUserID = Purchases.shared.appUserID
        listenForCustomerInfoUpdates()
        Task { await refreshCustomerInfo() }
        Task { await loadOfferings() }
#else
        log.notice("RevenueCat SDK not linked — premium features remain locked")
#endif
    }

    nonisolated static func grantsAccess(isPremium: Bool, to feature: PremiumFeature) -> Bool {
        switch feature.requiredTier {
        case .premium:
            return isPremium
        }
    }

    func hasAccess(to feature: PremiumFeature) -> Bool {
#if DEBUG
        if FitLogUITestLaunch.isActive { return true }
#endif
        return Self.grantsAccess(isPremium: isPremium, to: feature)
    }

    /// Test seam for unit tests — do not use in production UI.
#if DEBUG
    func setPremiumForTesting(_ premium: Bool) {
        isPremium = premium
        premiumDetails = premium
            ? PremiumAccessDetails(isActive: true, willRenew: true, expirationDate: nil, isPromotional: false)
            : .inactive
    }
#endif

    /// Returns true when the user may proceed; false when paywall should be shown.
    func requirePremium(for feature: PremiumFeature) -> Bool {
        hasAccess(to: feature)
    }

#if canImport(RevenueCat)
    func refreshCustomerInfo() async {
        guard isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
        } catch {
            lastErrorMessage = error.localizedDescription
            log.error("Failed to refresh customer info: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadOfferings() async {
        guard isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            offerings = try await PurchaseService.fetchOfferings()
            await refreshIntroEligibility()
        } catch {
            lastErrorMessage = error.localizedDescription
            log.error("Failed to load offerings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// True only when StoreKit/RevenueCat reports the user is eligible for an intro/trial on this product.
    func isIntroEligible(forProductID productID: String) -> Bool {
        introEligibilityByProductID[productID] == true
    }

    func purchase(package: Package) async -> Bool {
        guard isConfigured else {
            lastErrorMessage = PurchaseServiceError.notConfigured.localizedDescription
            return false
        }
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }
        do {
            AnalyticsService.shared.track(.purchaseStarted)
            let info = try await PurchaseService.purchase(package: package)
            apply(customerInfo: info)
            if isPremium {
                AnalyticsService.shared.track(.purchaseCompleted)
                return true
            }
            // StoreKit can succeed while the RevenueCat entitlement is not attached yet.
            if let synced = try? await PurchaseService.syncPurchases() {
                apply(customerInfo: synced)
            }
            if isPremium {
                AnalyticsService.shared.track(.purchaseCompleted)
                return true
            }
            let message = "Purchase completed but Premium is not active yet. Tap Restore purchases, or contact support with your App User ID."
            lastErrorMessage = message
            AnalyticsService.shared.track(.purchaseFailed, properties: ["message": "entitlement_not_active"])
            log.error("Purchase succeeded without active premium entitlement")
            return false
        } catch PurchaseServiceError.purchaseCancelled {
            AnalyticsService.shared.track(.purchaseCancelled)
            return false
        } catch {
            lastErrorMessage = error.localizedDescription
            AnalyticsService.shared.track(.purchaseFailed, properties: ["message": error.localizedDescription])
            return false
        }
    }

    private func refreshIntroEligibility() async {
        guard let packages = offerings?.current?.availablePackages, !packages.isEmpty else {
            introEligibilityByProductID = [:]
            return
        }
        let productIDs = packages.map(\.storeProduct.productIdentifier)
        let map = await Purchases.shared.checkTrialOrIntroDiscountEligibility(productIdentifiers: productIDs)
        var result: [String: Bool] = [:]
        for (id, eligibility) in map {
            result[id] = eligibility.status == .eligible
        }
        introEligibilityByProductID = result
    }

    func restorePurchases() async -> Bool {
        guard isConfigured else {
            lastErrorMessage = PurchaseServiceError.notConfigured.localizedDescription
            return false
        }
        isRestoring = true
        lastErrorMessage = nil
        defer { isRestoring = false }
        do {
            let info = try await PurchaseService.restorePurchases()
            apply(customerInfo: info)
            return isPremium
        } catch {
            lastErrorMessage = PurchaseRestoreMessaging.userFacingFailureMessage(for: error)
            return false
        }
    }

    func syncPurchases() async -> Bool {
        guard isConfigured else {
            lastErrorMessage = PurchaseServiceError.notConfigured.localizedDescription
            return false
        }
        isRestoring = true
        lastErrorMessage = nil
        defer { isRestoring = false }
        do {
            let info = try await PurchaseService.syncPurchases()
            apply(customerInfo: info)
            return isPremium
        } catch {
            lastErrorMessage = PurchaseRestoreMessaging.userFacingFailureMessage(for: error)
            return false
        }
    }

    /// Stable App User ID for Sign in with Apple users (enables promotional entitlements from dashboard).
    func logIn(appUserID: String) async {
        guard isConfigured else { return }
        do {
            let result = try await PurchaseService.logIn(appUserID: appUserID)
            apply(customerInfo: result.customerInfo)
            self.appUserID = Purchases.shared.appUserID
        } catch {
            lastErrorMessage = error.localizedDescription
            log.error("RevenueCat logIn failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func logOut() async {
        guard isConfigured else { return }
        do {
            let info = try await PurchaseService.logOut()
            apply(customerInfo: info)
            appUserID = Purchases.shared.appUserID
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func listenForCustomerInfoUpdates() {
        customerInfoTask?.cancel()
        customerInfoTask = Task { @MainActor [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                self?.apply(customerInfo: info)
            }
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        isPremium = PurchaseService.isPremiumActive(in: customerInfo)
        premiumDetails = PurchaseService.premiumAccessDetails(in: customerInfo)
        appUserID = Purchases.shared.appUserID
    }
#else
    func refreshCustomerInfo() async {}
    func loadOfferings() async {}
    func purchase(package: Any) async -> Bool { false }
    func restorePurchases() async -> Bool { false }
    func syncPurchases() async -> Bool { false }
    func logIn(appUserID: String) async {}
    func logOut() async {}
#endif
}
