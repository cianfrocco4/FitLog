//
//  ProgramGoalModels.swift
//  FitLog
//
//  Phase-scoped process goals for Guided Coach / dynamic programs.
//  Persisted inside the DynamicProgramState JSON blob (optional Codable fields).
//

import Foundation

// MARK: - Metric kinds

enum ProgramGoalMetricKind: String, Codable, CaseIterable, Sendable, Hashable {
    case sessionsPerWeek
    case weeklyHardSets
    case weeklyCardioMinutes

    var shortLabel: String {
        switch self {
        case .sessionsPerWeek: return "Sessions"
        case .weeklyHardSets: return "Hard sets"
        case .weeklyCardioMinutes: return "Cardio"
        }
    }

    var unitLabel: String {
        switch self {
        case .sessionsPerWeek: return "sessions"
        case .weeklyHardSets: return "hard sets"
        case .weeklyCardioMinutes: return "min"
        }
    }
}

// MARK: - Target source

enum ProgramGoalTargetSource: String, Codable, Sendable, Hashable {
    /// Recomputed from the current schedule whenever templates change.
    case auto
    /// User-edited; preserved across re-normalization.
    case userSet
}

// MARK: - Target

struct ProgramGoalTarget: Codable, Equatable, Hashable, Sendable {
    var kind: ProgramGoalMetricKind
    var value: Double
    /// Optional band; primary target is met when actual >= value - tolerance.
    var tolerance: Double?
    var isPrimary: Bool
    var source: ProgramGoalTargetSource

    init(
        kind: ProgramGoalMetricKind,
        value: Double,
        tolerance: Double? = nil,
        isPrimary: Bool = false,
        source: ProgramGoalTargetSource = .auto
    ) {
        self.kind = kind
        self.value = value
        self.tolerance = tolerance
        self.isPrimary = isPrimary
        self.source = source
    }

    var displayValue: String {
        switch kind {
        case .sessionsPerWeek:
            return "\(Int(value.rounded()))"
        case .weeklyHardSets:
            return "~\(Int(value.rounded()))"
        case .weeklyCardioMinutes:
            return "\(Int(value.rounded()))"
        }
    }

    var chipLabel: String {
        switch kind {
        case .sessionsPerWeek:
            let n = Int(value.rounded())
            return "\(n) session\(n == 1 ? "" : "s")"
        case .weeklyHardSets:
            return "~\(Int(value.rounded())) hard sets"
        case .weeklyCardioMinutes:
            return "\(Int(value.rounded())) min cardio"
        }
    }
}

// MARK: - Phase goal

struct ProgramPhaseGoal: Codable, Equatable, Hashable, Sendable {
    var title: String
    /// One plain-language sentence describing what the phase aims for.
    var summary: String
    var targets: [ProgramGoalTarget]
    var coachRationale: String?
    /// When true, title/summary are left alone by `ProgramPhaseGoalFactory` re-normalization.
    var copyIsUserSet: Bool

    enum CodingKeys: String, CodingKey {
        case title, summary, targets, coachRationale, copyIsUserSet
    }

    init(
        title: String,
        summary: String,
        targets: [ProgramGoalTarget],
        coachRationale: String? = nil,
        copyIsUserSet: Bool = false
    ) {
        self.title = title
        self.summary = summary
        self.targets = targets
        self.coachRationale = coachRationale
        self.copyIsUserSet = copyIsUserSet
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        targets = try c.decode([ProgramGoalTarget].self, forKey: .targets)
        coachRationale = try c.decodeIfPresent(String.self, forKey: .coachRationale)
        copyIsUserSet = try c.decodeIfPresent(Bool.self, forKey: .copyIsUserSet) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(summary, forKey: .summary)
        try c.encode(targets, forKey: .targets)
        try c.encodeIfPresent(coachRationale, forKey: .coachRationale)
        try c.encode(copyIsUserSet, forKey: .copyIsUserSet)
    }

    var primaryTarget: ProgramGoalTarget? {
        targets.first(where: \.isPrimary) ?? targets.first
    }

    var chipLabels: [String] {
        targets.map(\.chipLabel)
    }
}

// MARK: - Scorecard status

enum WeekGoalStatus: String, Codable, Sendable, Hashable {
    case upcoming
    case onTrack
    case atRisk
    case met
    case missed
    /// Zero planned sessions (fully busy, or before anchor) — excluded from phase denominator.
    case notScheduled

    var plainLanguageLabel: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .onTrack: return "On track"
        case .atRisk: return "Needs catch-up"
        case .met: return "Goal met"
        case .missed: return "Missed"
        case .notScheduled: return "Not scheduled"
        }
    }
}

struct MetricProgress: Equatable, Sendable, Hashable {
    var kind: ProgramGoalMetricKind
    var planned: Double
    var actual: Double
    var isPrimary: Bool

    var fraction: Double {
        guard planned > 0 else { return 0 }
        return min(1, actual / planned)
    }

    var isMet: Bool {
        actual + 0.001 >= planned
    }
}

struct WeekGoalScorecard: Equatable, Sendable, Identifiable {
    var id: String { isoWeekKey }
    var weekStart: Date
    var isoWeekKey: String
    var owningBlockId: UUID?
    var weekInBlock: Int?
    var isDeloadWeek: Bool
    var metrics: [MetricProgress]
    var status: WeekGoalStatus
    var statusSentence: String

    var primaryMetric: MetricProgress? {
        metrics.first(where: \.isPrimary) ?? metrics.first
    }
}

struct PhaseGoalProgress: Equatable, Sendable {
    var blockId: UUID
    var phaseGoal: ProgramPhaseGoal?
    var weeksMet: Int
    var weeksElapsed: Int
    var overallFraction: Double
    var weekScorecards: [WeekGoalScorecard]

    var completionLabel: String {
        guard weeksElapsed > 0 else { return "Not started" }
        return "\(weeksMet) of \(weeksElapsed) weeks on target"
    }
}
