//
//  PremiumFeature.swift
//  FitLog
//
//  Identifiers for premium-gated capabilities (analytics + paywall copy).
//

import Foundation

/// Subscription tiers used for feature gating. All Phase 1 features map to `.premium`.
enum PremiumTier: Sendable {
    case premium
}

enum PremiumFeature: String, CaseIterable, Sendable, Identifiable {
    case aiCoach
    case aiProgramGeneration
    case aiFormTips
    case aiWorkoutSuggestions
    case aiExerciseReview
    case readinessTrends
    case advancedAnalytics
    case unlimitedHistory
    case dataExport

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .aiCoach: return "AI Coach"
        case .aiProgramGeneration: return "AI Program Builder"
        case .aiFormTips: return "AI Form Tips"
        case .aiWorkoutSuggestions: return "AI Workout Suggestions"
        case .aiExerciseReview: return "AI Exercise Review"
        case .readinessTrends: return "Readiness Trends"
        case .advancedAnalytics: return "Advanced Analytics"
        case .unlimitedHistory: return "Unlimited History"
        case .dataExport: return "Data Export"
        }
    }

    var paywallBullet: String {
        switch self {
        case .aiCoach:
            return "Natural-language coaching with clear explanations"
        case .aiProgramGeneration:
            return "Generate and adapt training plans from your goals"
        case .aiFormTips:
            return "AI-assisted form cues for every exercise"
        case .aiWorkoutSuggestions:
            return "Smart balance and exercise suggestions"
        case .aiExerciseReview:
            return "AI review when creating custom exercises"
        case .readinessTrends:
            return "7–90 day readiness trends from Apple Health"
        case .advancedAnalytics:
            return "Muscle balance, recovery trends, and e1RM insights"
        case .unlimitedHistory:
            return "Full workout history with extended date ranges"
        case .dataExport:
            return "Export archives and CSV for backup or analysis"
        }
    }

    /// Primary bullets shown on the paywall hero list.
    static var paywallHighlights: [PremiumFeature] {
        [.aiCoach, .aiProgramGeneration, .readinessTrends, .advancedAnalytics, .unlimitedHistory]
    }

    /// Maps each feature to the subscription tier required. Extend when adding mid-tier SKUs.
    var requiredTier: PremiumTier {
        switch self {
        case .aiCoach, .aiProgramGeneration, .aiFormTips, .aiWorkoutSuggestions, .aiExerciseReview,
             .readinessTrends, .advancedAnalytics, .unlimitedHistory, .dataExport:
            return .premium
        }
    }
}
