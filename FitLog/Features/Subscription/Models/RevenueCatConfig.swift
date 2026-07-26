//
//  RevenueCatConfig.swift
//  FitLog
//
//  RevenueCat + App Store product configuration.
//

import Foundation

enum RevenueCatConfig {
    /// RevenueCat entitlement identifier — must match the dashboard.
    static let premiumEntitlementID = "premium"

    /// RevenueCat offering identifier — must match the dashboard default offering.
    static let defaultOfferingID = "default"

    /// Monthly subscription product ID (App Store Connect + RevenueCat).
    static let monthlyProductID = "workoutlogai_premium_monthly"

    /// Annual subscription product ID.
    static let annualProductID = "workoutlogai_premium_annual"

    /// Optional lifetime product ID for early adopters.
    static let lifetimeProductID = "workoutlogai_premium_lifetime"

    private static func trimmed(_ value: String) -> String? {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Public RevenueCat API key from env or Info.plist (`REVENUECAT_API_KEY`).
    static var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"].flatMap(trimmed) {
            return env
        }
        return (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String).flatMap(trimmed)
    }

    static var isConfigured: Bool { apiKey != nil }
}
