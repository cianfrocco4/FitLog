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
    /// Knee-dominant leg volume (quads, hip flexors) — coarse.
    var quadKneeOrientedSets: Int
    /// Hip hinge / posterior leg (hamstrings, glutes, posterior chain) — coarse.
    var hipPosteriorLegSets: Int
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

    struct Context: Equatable {
        var primaryGoal: String?
        var experienceLevel: String?
        var sessionDurationMinutes: Int?
        var priorityNotes: String?
        var variationMode: String?
        var sessionsPerWeek: Int?
        var desiredRotationLength: Int?
        var splitPreference: String?

        init(
            primaryGoal: String? = nil,
            experienceLevel: String? = nil,
            sessionDurationMinutes: Int? = nil,
            priorityNotes: String? = nil,
            variationMode: String? = nil,
            sessionsPerWeek: Int? = nil,
            desiredRotationLength: Int? = nil,
            splitPreference: String? = nil
        ) {
            self.primaryGoal = primaryGoal
            self.experienceLevel = experienceLevel
            self.sessionDurationMinutes = sessionDurationMinutes
            self.priorityNotes = priorityNotes
            self.variationMode = variationMode
            self.sessionsPerWeek = sessionsPerWeek
            self.desiredRotationLength = desiredRotationLength
            self.splitPreference = splitPreference
        }

        static let none = Context()
    }

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
        var quadKnee = 0
        var hipPost = 0
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
                        if bucketQuadKnee.contains(g) { quadKnee += s }
                        if bucketHipPosteriorLeg.contains(g) { hipPost += s }
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
            quadKneeOrientedSets: quadKnee,
            hipPosteriorLegSets: hipPost,
            distinctMuscleGroupsTouched: muscleKeys.count,
            inferredSplitStyle: style
        )
    }

    static func warnings(
        stats: SplitProposalProgramStats,
        days: [DayInput],
        context: Context = .none
    ) -> [SplitProposalProgramWarning] {
        var out: [SplitProposalProgramWarning] = []

        let dayTallies = pushPullDominantDayTallies(days: days)
        if dayTallies.pushDominantDays > dayTallies.pullDominantDays {
            out.append(SplitProposalProgramWarning(
                severity: .caution,
                message: "More push-focused training days (\(dayTallies.pushDominantDays)) than pull-focused days (\(dayTallies.pullDominantDays)). That biases shoulders and posture over time — add pull-focused templates, balance upper days, or regenerate (applies to any split: PPL, upper/lower, bro-style, etc.)."
            ))
        }

        if stats.legOrientedSets > 12,
           stats.quadKneeOrientedSets > max(12, stats.hipPosteriorLegSets * 2 + 6) {
            out.append(SplitProposalProgramWarning(
                severity: .caution,
                message: "Leg volume looks heavily knee/quad-dominant vs hip hinge and hamstrings/glutes. Add RDLs, hinges, leg curls, or similar for balance (any leg split)."
            ))
        }

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

        if let experience = context.experienceLevel?.lowercased(),
           experience.contains("beginner"),
           stats.totalHardSetsPerWeek > 75 {
            out.append(SplitProposalProgramWarning(
                severity: .caution,
                message: "For a beginner, weekly volume looks high (\(stats.totalHardSetsPerWeek) sets). Consider fewer accessory slots or 2–3 sets on smaller movements."
            ))
        }

        if let goal = context.primaryGoal?.lowercased(),
           goal.contains("strength"),
           stats.pushOrientedSets + stats.pullOrientedSets + stats.legOrientedSets > 0,
           stats.distinctMuscleGroupsTouched > 10 {
            out.append(SplitProposalProgramWarning(
                severity: .note,
                message: "Strength-focused plans often work best with fewer priorities per block. Make sure the main lifts are early and accessory volume does not crowd recovery."
            ))
        }

        if let minutes = context.sessionDurationMinutes, minutes <= 45 {
            let crowded = days.first { d in
                d.slots.count >= 6 || d.slots.reduce(0) { $0 + max(0, $1.sets) } > 20
            }
            if let d = crowded {
                out.append(SplitProposalProgramWarning(
                    severity: .caution,
                    message: "“\(d.name)” may be too crowded for ~\(minutes) minutes. Trim slots or lower sets so the plan is realistic."
                ))
            }
        }

        if let priority = context.priorityNotes?.lowercased(),
           !priority.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let touched = days.flatMap(\.slots).flatMap(\.targetMuscleNames).joined(separator: " ").lowercased()
            let priorityTokens = priority
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 }
            if !priorityTokens.isEmpty,
               priorityTokens.allSatisfy({ !touched.contains($0) }) {
                out.append(SplitProposalProgramWarning(
                    severity: .note,
                    message: "Your priority notes do not appear to map clearly onto the proposed muscle tags. Check that the plan includes your stated focus."
                ))
            }
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

        out.append(contentsOf: variationWarnings(days: days, context: context))

        return out
    }

    private static func variationWarnings(days: [DayInput], context: Context) -> [SplitProposalProgramWarning] {
        guard let modeRaw = context.variationMode?.lowercased(),
              !modeRaw.contains("simple"),
              !days.isEmpty else { return [] }
        var out: [SplitProposalProgramWarning] = []
        let names = days.map { $0.name.lowercased() }
        let split = context.splitPreference?.lowercased() ?? ""

        if let sessions = context.sessionsPerWeek,
           let rotation = context.desiredRotationLength,
           rotation > sessions + 2 {
            out.append(SplitProposalProgramWarning(
                severity: .note,
                message: "This uses a \(rotation)-workout rotation for \(sessions) sessions/week. That adds variety, but each exact workout repeats less often."
            ))
        }

        let wantsPPL = split.contains("ppl") || (split.contains("push") && split.contains("pull") && split.contains("leg"))
        if wantsPPL {
            let pushCount = names.filter { $0.contains("push") }.count
            let pullCount = names.filter { $0.contains("pull") }.count
            let legCount = names.filter { $0.contains("leg") || $0.contains("lower") }.count
            if let rotation = context.desiredRotationLength, rotation >= 6,
               min(pushCount, pullCount, legCount) < 2 {
                out.append(SplitProposalProgramWarning(
                    severity: .caution,
                    message: "PPL variation requested, but the rotation does not clearly include at least two Push, Pull, and Legs/Lower templates."
                ))
            }
        }

        let grouped = Dictionary(grouping: days) { baseVariationName($0.name) }
        for (base, variants) in grouped where variants.count >= 2 {
            let signatures = Set(variants.map { daySignature($0) })
            if signatures.count == 1, !signatures.isEmpty {
                out.append(SplitProposalProgramWarning(
                    severity: .note,
                    message: "\(base) variants look very similar. Change angles, default exercises, or muscle emphasis so A/B days feel meaningfully different."
                ))
                break
            }
        }

        if modeRaw.contains("high"),
           context.experienceLevel?.lowercased().contains("beginner") == true {
            out.append(SplitProposalProgramWarning(
                severity: .note,
                message: "High variety can slow skill practice for beginners. Keep key compounds consistent if progress stalls."
            ))
        }

        return out
    }

    private static func baseVariationName(_ name: String) -> String {
        var key = name.lowercased()
        for suffix in [" a", " b", " c", " 1", " 2", " 3"] {
            if key.hasSuffix(suffix) {
                key.removeLast(suffix.count)
                break
            }
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func daySignature(_ day: DayInput) -> String {
        day.slots
            .map { slot in
                let muscles = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
                    .map(\.rawValue)
                    .sorted()
                    .joined(separator: ",")
                let label = slot.label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(label)|\(muscles)|\(slot.sets)"
            }
            .joined(separator: ";")
    }

    /// Per training day: compare slot volume whose muscles skew push vs pull (legs/core days often neutral).
    private static func pushPullDominantDayTallies(days: [DayInput]) -> (pushDominantDays: Int, pullDominantDays: Int) {
        let setGapToCallDominant = 6
        var pushDominantDays = 0
        var pullDominantDays = 0
        for day in days {
            var dayPush = 0
            var dayPull = 0
            for slot in day.slots {
                let s = min(max(slot.sets, 0), 99)
                let groups = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
                if groups.isEmpty { continue }
                var pushHits = 0
                var pullHits = 0
                var legHits = 0
                for g in groups {
                    if bucketPush.contains(g) { pushHits += 1 }
                    if bucketPull.contains(g) { pullHits += 1 }
                    if bucketLegs.contains(g) { legHits += 1 }
                }
                // Leg-only or mostly leg slots don't count toward upper push/pull imbalance.
                if legHits > max(pushHits, pullHits) { continue }
                if pushHits > pullHits {
                    dayPush += s
                } else if pullHits > pushHits {
                    dayPull += s
                } else if pushHits > 0 && pushHits == pullHits {
                    dayPush += s / 2
                    dayPull += s - s / 2
                }
            }
            if dayPush >= dayPull + setGapToCallDominant {
                pushDominantDays += 1
            } else if dayPull >= dayPush + setGapToCallDominant {
                pullDominantDays += 1
            }
        }
        return (pushDominantDays, pullDominantDays)
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

    /// For lower-body balance hints (knee vs hinge / posterior).
    private static let bucketQuadKnee: Set<MuscleGroup> = [
        .quads, .hipFlexors
    ]

    private static let bucketHipPosteriorLeg: Set<MuscleGroup> = [
        .hamstrings, .glutes, .posteriorChain
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
