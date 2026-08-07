//
//  PremiumGatedSelection.swift
//  FitLog
//
//  Shared reject-and-paywall selection helpers for Premium-gated pickers.
//

import SwiftUI

enum PremiumGatedSelection {
    /// Whether a Premium-gated proposed value may be applied for the current entitlement.
    static func shouldApply(requiresPremium: Bool, hasPremiumAccess: Bool) -> Bool {
        !requiresPremium || hasPremiumAccess
    }

    /// Binding that rejects Premium-only values without mutating `get`, then invokes `onDenied`.
    /// Pass `resyncToken` for controls (especially segmented pickers) that need a forced rebuild
    /// when `set` intentionally ignores the proposed value.
    static func binding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void,
        requiresPremium: @escaping (Value) -> Bool,
        hasPremiumAccess: @escaping () -> Bool,
        onDenied: @escaping () -> Void,
        resyncToken: Binding<Int>? = nil
    ) -> Binding<Value> {
        Binding(
            get: get,
            set: { newValue in
                guard shouldApply(
                    requiresPremium: requiresPremium(newValue),
                    hasPremiumAccess: hasPremiumAccess()
                ) else {
                    onDenied()
                    if let resyncToken {
                        resyncToken.wrappedValue &+= 1
                    }
                    return
                }
                set(newValue)
            }
        )
    }
}
