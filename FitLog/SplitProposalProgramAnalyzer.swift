//
//  SplitProposalProgramAnalyzer.swift
//  FitLog
//
//  Local, deterministic analysis of an editable split proposal (no network).
//  Used for preview summaries and balance hints — not medical advice.
//

import Foundation

struct SplitProposalProgramStats: Equatable {
    /// Sum of slot sets across all proposed training days (one count per slot).
    var totalHardSetsPerWeek: Int
    /// Aggregated “effective sets” attributed to broad movement buckets (a slot’s sets count toward each resolved muscle’s bucket once).
    var pushOrientedSets: Int
    var pullOrientedSets: Int
    var legOrientedSets: Int
    var distinctMuscleGroupsTouched: Int
    /// Short label such as “Push / Pull / Legs” when names match.
    var inferredSplitStyle: String
}

struct SplitProposalProgramWarning: Equatable, Identifiable {
    var id: String { message }
    let severity: Severity
    let message: String

    enum Severity: String {
        case caution
        case note
    }
}

enum SplitProposalProgramAnalyzer {

    /// Slot-like input for preview (matches editable split builder rows).
    struct SlotInput: Equatable {
        var label: String
        var targetMuscleNames: [String]
        var sets: Int
    }

    struct DayInput: Equatable {
        var name: String
        var focus: String
        var slots: [SlotInput]
    }

    static func stats(for days: [DayInput]) -> SplitProposalProgramStats {
        var totalSets = 0
        var push = 0
        var pull = 0
        var legs = 0
        var muscleKeys = Set<String>()

        for day in days {
            for slot in day.slots {
                let s = min(max(slot.sets, 0), 99)
                totalSets += s
                let groups = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
                if groups.isEmpty {
                    muscleKeys.insert(MuscleGroup.other.rawValue)
                } else {
                    for g in groups {
                        muscleKeys.insert(g.rawValue)
                        if bucketPush.contains(g) { push += s }
                        if bucketPull.contains(g) { pull += s }
                        if bucketLegs.contains(g) { legs += s }
                    }
                }
            }
        }

        let style = inferSplitStyle(dayNames: days.map(\.name))
        return SplitProposalProgramStats(
            totalHardSetsPerWeek: totalSets,
            pushOrientedSets: push,
            pullOrientedSets: pull,
            legOrientedSets: legs,
            distinctMuscleGroupsTouched: muscleKeys.count,
            inferredSplitStyle: style
        )
    }

    static func warnings(stats: SplitProposalProgramStats, days: [DayInput]) -> [SplitProposalProgramWarning] {
        var out: [SplitProposalProgramWarning] = []

        if stats.legOrientedSets == 0 {
            out.append(SplitProposalProgramWarning(
                severity: .caution,
                message: "No clear leg-focused volume (quads, hamstrings, glutes, calves). Consider adding lower-body work unless this block is intentional."
            ))
        }

        if stats.pullOrientedSets == 0 && stats.pushOrientedSets > 0 {
            out.append(SplitProposalProgramWarning(
                severity: .caution,
                message: "Pushing volume is present but pulling looks missing. Balance rows, rear delts, and biceps for shoulder and posture health."
            ))
        }

        if stats.pushOrientedSets == 0 && stats.pullOrientedSets > 0 {
            out.append(SplitProposalProgramWarning(
                severity: .note,
                message: "Little or no chest/front-delts/triceps emphasis detected. Confirm that matches your goals."
            ))
        }

        if stats.pushOrientedSets > 0, stats.pullOrientedSets > 0 {
            let ratio = Double(stats.pushOrientedSets) / Double(max(1, stats.pullOrientedSets))
            if ratio > 2.2 {
                out.append(SplitProposalProgramWarning(
                    severity: .caution,
                    message: "Pushing volume is much higher than pulling. Consider more rows, pulldowns, or rear-delt work."
                ))
            }
        }

        if stats.totalHardSetsPerWeek > 115 {
            out.append(SplitProposalProgramWarning(
                severity: .caution,
                message: "Weekly set count is very high (\(stats.totalHardSetsPerWeek)). Advanced users may tolerate this; others should trim accessories or add rest."
            ))
        }

        if stats.totalHardSetsPerWeek > 0, stats.totalHardSetsPerWeek < 45 {
            out.append(SplitProposalProgramWarning(
                severity: .note,
                message: "Weekly set count is on the low side (\(stats.totalHardSetsPerWeek)). Fine for maintenance or busy weeks — bump volume if you’re prioritizing growth."
            ))
        }

        let thinDay = days.first { d in
            let n = d.slots.count
            return n > 0 && n < 3
        }
        if let d = thinDay {
            out.append(SplitProposalProgramWarning(
                severity: .note,
                message: "“\(d.name)” has fewer than 3 slots — OK for time-crunched days; ensure other days carry priority work."
            ))
        }

        return out
    }

    // MARK: - Buckets (coarse, for hints only)

    private static let bucketPush: Set<MuscleGroup> = [
        .chest, .upperChest, .lowerChest,
        .frontDelts, .sideDelts,
        .triceps, .serratusAnterior
    ]

    private static let bucketPull: Set<MuscleGroup> = [
        .lats, .upperBack, .midBack, .rhomboids, .traps, .lowerBack,
        .rearDelts, .biceps, .brachialis, .forearms,
        .rotatorCuff, .posteriorChain
    ]

    private static let bucketLegs: Set<MuscleGroup> = [
        .quads, .hamstrings, .glutes, .calves, .soleus,
        .adductors, .abductors, .hipFlexors
    ]

    private static func inferSplitStyle(dayNames: [String]) -> String {
        let joined = dayNames.joined(separator: " ").lowercased()
        let count = dayNames.count
        if count >= 3,
           joined.contains("push"), joined.contains("pull"),
           joined.contains("leg") || joined.contains("lower") {
            return "Push / Pull / Legs (inferred)"
        }
        if count == 2,
           (joined.contains("upper") && joined.contains("lower"))
            || (joined.contains("upper") && joined.contains("leg")) {
            return "Upper / Lower (inferred)"
        }
        if count == 1 || (count <= 2 && joined.contains("full")) {
            return "Full body / minimal split (inferred)"
        }
        if count >= 5, joined.contains("chest") || joined.contains("back") || joined.contains("arm") {
            return "Bro-style rotation (inferred)"
        }
        if count > 0 {
            return "Custom rotation (\(count) training templates)"
        }
        return "—"
    }
}
