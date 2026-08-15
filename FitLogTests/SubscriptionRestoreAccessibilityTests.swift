//
//  SubscriptionRestoreAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct SubscriptionRestoreAccessibilityTests {

    @Test func restoreLabelSwitchesWhileRestoring() {
        #expect(
            SubscriptionRestoreAccessibility.restoreLabel(
                isRestoring: false,
                idleLabel: SubscriptionRestoreAccessibility.settingsIdleLabel
            ) == "Restore / Refresh access"
        )
        #expect(
            SubscriptionRestoreAccessibility.restoreLabel(
                isRestoring: true,
                idleLabel: SubscriptionRestoreAccessibility.settingsIdleLabel
            ) == "Restoring purchases"
        )
    }

    @Test func restoringCaptionMatchesPaywallCopy() {
        #expect(SubscriptionRestoreAccessibility.restoringCaption == "Restoring…")
    }
}
