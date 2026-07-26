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
