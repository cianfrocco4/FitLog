//
//  SubscriptionRestoreAccessibility.swift
//  FitLog
//

import Foundation

enum SubscriptionRestoreAccessibility {
    static func restoreLabel(isRestoring: Bool, idleLabel: String) -> String {
        isRestoring ? "Restoring purchases" : idleLabel
    }

    static var restoringCaption: String { "Restoring…" }

    static var settingsIdleLabel: String { "Restore / Refresh access" }

    static var settingsHint: String {
        "Refreshes subscription status from the App Store and RevenueCat"
    }
}
