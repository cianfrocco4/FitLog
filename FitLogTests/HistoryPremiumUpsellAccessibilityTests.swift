//
//  HistoryPremiumUpsellAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct HistoryPremiumUpsellAccessibilityTests {

    @Test func unlockLabels_areDistinctPerUpsell() {
        #expect(
            HistoryPremiumUpsellAccessibility.unlockLabel(for: .fullTrainingHistory)
                == "Unlock Premium for full training history"
        )
        #expect(
            HistoryPremiumUpsellAccessibility.unlockLabel(for: .advancedAnalytics)
                == "Unlock Premium for advanced analytics"
        )
        #expect(
            HistoryPremiumUpsellAccessibility.unlockLabel(for: .fullTrainingHistory)
                != HistoryPremiumUpsellAccessibility.unlockLabel(for: .advancedAnalytics)
        )
    }

    @Test func unlockHints_describeFeatureBenefit() {
        #expect(
            HistoryPremiumUpsellAccessibility.unlockHint(for: .fullTrainingHistory)
                .contains("heatmap")
        )
        #expect(
            HistoryPremiumUpsellAccessibility.unlockHint(for: .advancedAnalytics)
                .contains("muscle balance")
        )
    }
}
