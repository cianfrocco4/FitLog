//
//  PaywallPurchaseAccessibility.swift
//  FitLog
//
//  VoiceOver copy for the paywall purchase CTA (including in-flight purchase).
//

import Foundation

enum PaywallPurchaseAccessibility {
    /// Primary label for the purchase button.
    static func purchaseLabel(isPurchasing: Bool, ctaTitle: String) -> String {
        if isPurchasing {
            return "Purchasing"
        }
        return ctaTitle
    }

    /// Hint describing what the purchase button will do, or that purchase is in progress.
    static func purchaseHint(isPurchasing: Bool) -> String {
        if isPurchasing {
            return "Completing purchase with the App Store"
        }
        return "Starts purchase with Apple"
    }
}
