//
//  SubscriptionCatalog.swift
//  FitLog
//
//  Auto-renewable SKUs shown on the paywall. Static copy is the 3.1.2(c) fallback
//  when StoreKit products fail to load; live prices come from SubscriptionStoreView.
//

import Foundation

enum SubscriptionCatalog {
    struct Plan: Identifiable, Equatable, Sendable {
        var id: String { productID }
        let productID: String
        let title: String
        let duration: String
        let listPriceUSD: String
        let disclosure: String
    }

    /// Monthly and annual only — do not list lifetime here (non-consumable; omit unless submitted in ASC).
    static let autoRenewablePlans: [Plan] = [
        Plan(
            productID: RevenueCatConfig.monthlyProductID,
            title: "Premium Monthly",
            duration: "1 month",
            listPriceUSD: "$5.99",
            disclosure: "14 days free, then $5.99/month. Auto-renews until cancelled."
        ),
        Plan(
            productID: RevenueCatConfig.annualProductID,
            title: "Premium Annual",
            duration: "1 year",
            listPriceUSD: "$49.99",
            disclosure: "14 days free, then $49.99/year. Auto-renews until cancelled."
        )
    ]

    static var autoRenewableProductIDs: [String] {
        autoRenewablePlans.map(\.productID)
    }
}
