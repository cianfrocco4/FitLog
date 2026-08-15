//
//  HistoryPremiumUpsellAccessibility.swift
//  FitLog
//
//  VoiceOver copy for History overview Premium unlock CTAs.
//

import Foundation

enum HistoryPremiumUpsellKind: Equatable {
    case fullTrainingHistory
    case advancedAnalytics
}

enum HistoryPremiumUpsellAccessibility {
    /// Distinct spoken labels so both “Unlock Premium” buttons are distinguishable.
    static func unlockLabel(for kind: HistoryPremiumUpsellKind) -> String {
        switch kind {
        case .fullTrainingHistory:
            return "Unlock Premium for full training history"
        case .advancedAnalytics:
            return "Unlock Premium for advanced analytics"
        }
    }

    static func unlockHint(for kind: HistoryPremiumUpsellKind) -> String {
        switch kind {
        case .fullTrainingHistory:
            return "Shows Premium options for the 365-day heatmap and extended date ranges"
        case .advancedAnalytics:
            return "Shows Premium options for muscle balance, recovery trends, and volume charts"
        }
    }
}
