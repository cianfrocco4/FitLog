//
//  PurchaseService.swift
//  FitLog
//
//  Thin StoreKit 2 wrapper via RevenueCat for purchases and restore.
//

import Foundation

#if canImport(RevenueCat)
import RevenueCat
#endif

enum PurchaseServiceError: LocalizedError {
    case notConfigured
    case noPackageSelected
    case purchaseCancelled
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Subscriptions are not configured yet."
        case .noPackageSelected:
            return "Select a subscription plan to continue."
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .underlying(let message):
            return message
        }
    }
}

enum PurchaseService {
#if canImport(RevenueCat)
    /// True only after `Purchases.configure` — never use `RevenueCatConfig.isConfigured` alone;
    /// an API key in Info.plist does not mean the SDK was initialized (e.g. UI/unit test host).
    private static var isSDKReady: Bool { Purchases.isConfigured }

    static func fetchOfferings() async throws -> Offerings {
        guard isSDKReady else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.offerings()
    }

    static func purchase(package: Package) async throws -> CustomerInfo {
        guard isSDKReady else { throw PurchaseServiceError.notConfigured }
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            throw PurchaseServiceError.purchaseCancelled
        }
        return result.customerInfo
    }

    static func restorePurchases() async throws -> CustomerInfo {
        guard isSDKReady else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.restorePurchases()
    }

    static func syncPurchases() async throws -> CustomerInfo {
        guard isSDKReady else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.syncPurchases()
    }

    static func logIn(appUserID: String) async throws -> (customerInfo: CustomerInfo, created: Bool) {
        guard isSDKReady else { throw PurchaseServiceError.notConfigured }
        let result = try await Purchases.shared.logIn(appUserID)
        return (result.customerInfo, result.created)
    }

    static func logOut() async throws -> CustomerInfo {
        guard isSDKReady else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.logOut()
    }

    static func currentAppUserID() -> String {
        guard isSDKReady else { return "unavailable" }
        return Purchases.shared.appUserID
    }

    static func isPremiumActive(in customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements[RevenueCatConfig.premiumEntitlementID]?.isActive == true
    }

    /// Maps RevenueCat entitlement fields for Subscription UI.
    /// Canceling in App Store sets `willRenew` to false but keeps `isActive` until `expirationDate`.
    static func premiumAccessDetails(in customerInfo: CustomerInfo) -> PremiumAccessDetails {
        guard let entitlement = customerInfo.entitlements[RevenueCatConfig.premiumEntitlementID],
              entitlement.isActive
        else {
            return .inactive
        }
        let isPromotional = entitlement.store == .promotional
            || entitlement.productIdentifier.hasPrefix("rc_promo")
        return PremiumAccessDetails(
            isActive: true,
            willRenew: entitlement.willRenew,
            expirationDate: entitlement.expirationDate,
            isPromotional: isPromotional
        )
    }
#else
    static func fetchOfferings() async throws -> Never { throw PurchaseServiceError.notConfigured }
    static func purchase(package: Any) async throws -> Never { throw PurchaseServiceError.notConfigured }
    static func restorePurchases() async throws -> Never { throw PurchaseServiceError.notConfigured }
    static func syncPurchases() async throws -> Never { throw PurchaseServiceError.notConfigured }
    static func logIn(appUserID: String) async throws -> (customerInfo: Any, created: Bool) {
        throw PurchaseServiceError.notConfigured
    }
    static func logOut() async throws -> Never { throw PurchaseServiceError.notConfigured }
    static func currentAppUserID() -> String { "unavailable" }
    static func isPremiumActive(in customerInfo: Any) -> Bool { false }
    static func premiumAccessDetails(in customerInfo: Any) -> PremiumAccessDetails { .inactive }
#endif
}
