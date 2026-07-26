//
//  ReadinessScore.swift
//  FitLog
//

import Foundation

enum ReadinessBand: String, Codable, Sendable {
    case low
    case moderate
    case good
    case optimal

    var displayTitle: String {
        switch self {
        case .low: return "Low readiness"
        case .moderate: return "Moderate readiness"
        case .good: return "Good readiness"
        case .optimal: return "Optimal readiness"
        }
    }

    var coachingHint: String {
        switch self {
        case .low:
            return "Consider lighter volume, technique work, or an extra rest day."
        case .moderate:
            return "Train as planned but avoid pushing every set to failure."
        case .good:
            return "You're recovered enough for a solid training day."
        case .optimal:
            return "Great recovery — a strong day for key lifts or PR attempts."
        }
    }
}

struct ReadinessScore: Identifiable, Equatable, Sendable {
    let id: UUID
    let dayKey: String
    let computedAt: Date
    let score: Int
    let band: ReadinessBand
    let summary: String
    let components: [ReadinessComponent]

    var availableComponentCount: Int {
        components.filter(\.isAvailable).count
    }
}

extension ReadinessScore {
    static func placeholder(dayKey: String) -> ReadinessScore {
        ReadinessScore(
            id: UUID(),
            dayKey: dayKey,
            computedAt: Date(),
            score: 0,
            band: .moderate,
            summary: "Connect Apple Health to see your readiness score.",
            components: []
        )
    }
}
