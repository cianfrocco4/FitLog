//
//  OnDeviceAIModels.swift
//  FitLog
//
//  Domain models for on-device / routed AI proposals (app-wide, no FoundationModels import).
//

import Foundation

enum OnDeviceAIAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var userFacingMessage: String {
        switch self {
        case .available:
            return "On-device Apple Intelligence is available."
        case .unavailable(let reason):
            return reason
        }
    }
}

enum AIRouteUsed: String, Codable, Sendable {
    case onDevice
    case cloud
    case heuristic
}

/// Action kinds the Daily Adjust flow can apply to today's plan.
enum DailyAdjustActionKind: String, Codable, Sendable, CaseIterable {
    case makeLighter
    case markRest
    case keepAsPlanned
    case swapFocusNote
}

struct DailyAdjustmentChange: Equatable, Codable, Sendable, Identifiable {
    var id: String { "\(kind.rawValue)-\(detail)" }
    var kind: DailyAdjustActionKind
    var detail: String
}

struct DailyAdjustmentProposal: Equatable, Codable, Sendable {
    var summary: String
    var changes: [DailyAdjustmentChange]
    var rationale: String
    /// Always true in generated output; UI shows medical disclaimer separately.
    var disclaimerAck: Bool
    var routeUsed: AIRouteUsed
}

struct WeeklyInsight: Equatable, Codable, Sendable {
    var weekKey: String
    var title: String
    var narrative: String
    var highlights: [String]
    var risks: [String]
    var nextActions: [String]
    var routeUsed: AIRouteUsed
    var generatedAt: Date
}

struct ExerciseSubstitutionCandidate: Equatable, Codable, Sendable, Identifiable {
    var id: UUID
    var exerciseName: String
    var rationale: String
}

struct FormCueResult: Equatable, Codable, Sendable {
    var cues: [String]
    var routeUsed: AIRouteUsed
}

struct DailyAdjustContextPack: Equatable, Sendable {
    var dayKey: String
    var readinessScore: Int?
    var readinessSummary: String
    var plannedWorkoutName: String
    var plannedWorkoutDetail: String
    var recentLoadSummary: String
    var userNote: String
    var hasDynamicProgram: Bool
}
