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

enum PurchaseRestoreMessaging {
    static let noActiveSubscription = "No active subscription found for this Apple ID."
    static let networkFailure = "Couldn't reach the App Store. Check your connection and try again."
    static let genericFailure = "Couldn't restore purchases. Try again in a moment. If this continues, confirm this Apple ID has an active subscription."

    /// Maps StoreKit / RevenueCat / URL failures into short restore copy.
    /// Network-ish failures get connection guidance; other errors stay readable without raw SDK dumps when possible.
    static func userFacingFailureMessage(for error: Error) -> String {
        if let purchaseError = error as? PurchaseServiceError {
            return purchaseError.errorDescription ?? genericFailure
        }

        if isLikelyNetworkFailure(error) {
            return networkFailure
        }

        let localized = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if localized.isEmpty {
            return genericFailure
        }
        // Prefer a short generic line when the system string is a long opaque dump.
        if localized.count > 160 {
            return genericFailure
        }
        return localized
    }

    static func isLikelyNetworkFailure(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return Self.networkURLErrorCodes.contains(urlError.code)
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           let code = URLError.Code(rawValue: nsError.code),
           Self.networkURLErrorCodes.contains(code) {
            return true
        }
        // RevenueCat often wraps connectivity under NSError with URLError codes in `userInfo`.
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isLikelyNetworkFailure(underlying)
        }
        return false
    }

    private static let networkURLErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .internationalRoamingOff,
        .dataNotAllowed,
        .secureConnectionFailed
    ]
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
