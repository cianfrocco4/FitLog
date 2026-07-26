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
    static func fetchOfferings() async throws -> Offerings {
        guard RevenueCatConfig.isConfigured else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.offerings()
    }

    static func purchase(package: Package) async throws -> CustomerInfo {
        guard RevenueCatConfig.isConfigured else { throw PurchaseServiceError.notConfigured }
        let result = try await Purchases.shared.purchase(package: package)
        if result.userCancelled {
            throw PurchaseServiceError.purchaseCancelled
        }
        return result.customerInfo
    }

    static func restorePurchases() async throws -> CustomerInfo {
        guard RevenueCatConfig.isConfigured else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.restorePurchases()
    }

    static func syncPurchases() async throws -> CustomerInfo {
        guard RevenueCatConfig.isConfigured else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.syncPurchases()
    }

    static func logIn(appUserID: String) async throws -> (customerInfo: CustomerInfo, created: Bool) {
        guard RevenueCatConfig.isConfigured else { throw PurchaseServiceError.notConfigured }
        let result = try await Purchases.shared.logIn(appUserID)
        return (result.customerInfo, result.created)
    }

    static func logOut() async throws -> CustomerInfo {
        guard RevenueCatConfig.isConfigured else { throw PurchaseServiceError.notConfigured }
        return try await Purchases.shared.logOut()
    }

    static func currentAppUserID() -> String {
        Purchases.shared.appUserID
    }

    static func isPremiumActive(in customerInfo: CustomerInfo) -> Bool {
        customerInfo.entitlements[RevenueCatConfig.premiumEntitlementID]?.isActive == true
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
#endif
}
