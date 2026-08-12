//
//  PaywallPurchaseAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct PaywallPurchaseAccessibilityTests {

    @Test func purchaseLabel_switchesWhilePurchasing() {
        #expect(
            PaywallPurchaseAccessibility.purchaseLabel(
                isPurchasing: false,
                ctaTitle: "Continue with Premium"
            ) == "Continue with Premium"
        )
        #expect(
            PaywallPurchaseAccessibility.purchaseLabel(
                isPurchasing: true,
                ctaTitle: "Continue with Premium"
            ) == "Purchasing"
        )
    }

    @Test func purchaseHint_explainsInFlightState() {
        #expect(
            PaywallPurchaseAccessibility.purchaseHint(isPurchasing: false)
                == "Starts purchase with Apple"
        )
        #expect(
            PaywallPurchaseAccessibility.purchaseHint(isPurchasing: true)
                == "Completing purchase with the App Store"
        )
    }
}
