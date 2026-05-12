//
//  SetSchemeModels.swift
//  FitLog
//
//  Rich set/rep schemes, slot grouping, and per-slot progression for manual program building.
//  All types are Codable for persistence inside `DynamicProgramState` JSON.
//

import Foundation

// MARK: - Set scheme

/// How working sets are prescribed for a slot (beyond simple sets × reps).
enum SetSchemeKind: String, Codable, CaseIterable, Sendable, Hashable, Equatable {
    case fixed
    case pyramid
    case reversePyramid
    case rpeBased
    case rirBased
    case percentOf1RM
    case dropSet
    case restPause
    case amrap
}

/// Structured prescription pattern; `nil` on a slot means “fixed” classic sets/reps only.
struct SetScheme: Codable, Equatable, Hashable, Sendable {
    var kind: SetSchemeKind
    /// Target RPE (e.g. 8.0) when `kind == .rpeBased`.
    var rpeTarget: Double?
    /// Target RIR (e.g. 2.0) when `kind == .rirBased`.
    var rirTarget: Double?
    /// Percent of estimated 1RM (e.g. 75) when `kind == .percentOf1RM`.
    var percentOneRM: Double?
    /// Number of drop steps after the top set when `kind == .dropSet`.
    var dropSteps: Int?

    init(
        kind: SetSchemeKind = .fixed,
        rpeTarget: Double? = nil,
        rirTarget: Double? = nil,
        percentOneRM: Double? = nil,
        dropSteps: Int? = nil
    ) {
        self.kind = kind
        self.rpeTarget = rpeTarget
        self.rirTarget = rirTarget
        self.percentOneRM = percentOneRM
        self.dropSteps = dropSteps
    }

    /// User-facing short label for chips and timeline.
    var displayLabel: String {
        switch kind {
        case .fixed: return "Fixed"
        case .pyramid: return "Pyramid"
        case .reversePyramid: return "Rev. pyramid"
        case .rpeBased: return "RPE" + (rpeTarget.map { " \($0)" } ?? "")
        case .rirBased: return "RIR" + (rirTarget.map { " \($0)" } ?? "")
        case .percentOf1RM: return "%1RM" + (percentOneRM.map { " \($0)%" } ?? "")
        case .dropSet: return "Drop" + (dropSteps.map { " ×\($0)" } ?? "")
        case .restPause: return "Rest-pause"
        case .amrap: return "AMRAP"
        }
    }

    /// Returns a user-visible validation message, or `nil` if the scheme is consistent.
    func validationMessageIfInvalid() -> String? {
        switch kind {
        case .fixed:
            return nil
        case .pyramid, .reversePyramid, .restPause, .amrap:
            return nil
        case .rpeBased:
            guard let r = rpeTarget, r >= 1, r <= 10 else { return "RPE should be between 1 and 10." }
            return nil
        case .rirBased:
            guard let r = rirTarget, r >= 0, r <= 6 else { return "RIR should be between 0 and 6." }
            return nil
        case .percentOf1RM:
            guard let p = percentOneRM, p > 0, p <= 120 else { return "Percent 1RM should be between 1 and 120." }
            return nil
        case .dropSet:
            guard let d = dropSteps, d >= 1, d <= 5 else { return "Drop steps should be between 1 and 5." }
            return nil
        }
    }
}

// MARK: - Exercise grouping (supersets / circuits)

enum ExerciseGroupingKind: String, Codable, CaseIterable, Sendable, Hashable, Equatable {
    case standalone
    case superset
    case triset
    case circuit
    case giantSet
}

/// Links a slot to partner slots in the same day (by slot id). Empty partners = standalone.
struct ExerciseGrouping: Codable, Equatable, Hashable, Sendable {
    var kind: ExerciseGroupingKind
    /// Other slot IDs in this grouping (same `BlockWeeklyTemplate`); empty when standalone.
    var partnerSlotIds: [UUID]

    init(kind: ExerciseGroupingKind = .standalone, partnerSlotIds: [UUID] = []) {
        self.kind = kind
        self.partnerSlotIds = partnerSlotIds
    }

    var displayLabel: String {
        switch kind {
        case .standalone: return ""
        case .superset: return "Superset"
        case .triset: return "Triset"
        case .circuit: return "Circuit"
        case .giantSet: return "Giant set"
        }
    }
}

// MARK: - Per-slot progression override

enum SlotProgressionKind: String, Codable, CaseIterable, Sendable, Hashable, Equatable {
    /// Use `ProgramBlock.progressionStrategy`.
    case inheritFromBlock
    case linearWeightStep
    case doubleProgression
    case waveLoading
    case undulatingMicrocycle
}

struct SlotProgressionRule: Codable, Equatable, Hashable, Sendable {
    var kind: SlotProgressionKind
    /// When `kind == .linearWeightStep`, suggested add per week (kg).
    var weightIncrementKg: Double?

    init(kind: SlotProgressionKind = .inheritFromBlock, weightIncrementKg: Double? = nil) {
        self.kind = kind
        self.weightIncrementKg = weightIncrementKg
    }

    var displayLabel: String {
        switch kind {
        case .inheritFromBlock: return "Block default"
        case .linearWeightStep: return "Linear +" + (weightIncrementKg.map { " \($0) kg" } ?? "")
        case .doubleProgression: return "Double progression"
        case .waveLoading: return "Wave loading"
        case .undulatingMicrocycle: return "Undulating"
        }
    }
}
