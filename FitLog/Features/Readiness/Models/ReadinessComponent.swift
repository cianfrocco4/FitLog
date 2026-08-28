//
//  ReadinessComponent.swift
//  FitLog
//

import Foundation

enum ReadinessComponentKind: String, Codable, CaseIterable, Sendable {
    case hrv
    case restingHeartRate
    case sleep
    case trainingLoad

    var displayTitle: String {
        switch self {
        case .hrv: return "HRV"
        case .restingHeartRate: return "Resting HR"
        case .sleep: return "Sleep"
        case .trainingLoad: return "Training load"
        }
    }

    var systemImage: String {
        switch self {
        case .hrv: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        case .sleep: return "bed.double.fill"
        case .trainingLoad: return "figure.strengthtraining.traditional"
        }
    }

    /// Extra "how this works" copy shown under the component in Readiness details.
    var methodologyExplanation: String? {
        switch self {
        case .trainingLoad:
            return "Hard sets are working, drop, failure, and AMRAP sets with logged reps from workouts you finished in the last 72 hours. Warm-ups, timed holds, and cardio do not count. That total is compared with your typical 72-hour load from the last 28 days. Well below typical is light; near typical is normal; well above typical is elevated or high."
        case .hrv, .restingHeartRate, .sleep:
            return nil
        }
    }
}

struct ReadinessComponent: Identifiable, Equatable, Sendable {
    let kind: ReadinessComponentKind
    let score: Double
    let weight: Double
    let detail: String
    let isAvailable: Bool

    var id: String { kind.rawValue }

    var weightedContribution: Double {
        guard isAvailable else { return 0 }
        return score * weight
    }
}
