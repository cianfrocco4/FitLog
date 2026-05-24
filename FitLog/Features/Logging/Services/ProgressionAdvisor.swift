//
//  ProgressionAdvisor.swift
//  FitLog
//
//  Heuristic progression suggestions for the inline quick-log row.
//  Rules: linear load increment for compounds, double-progression for accessories,
//  deload nudge after 2+ missed sessions in a row.
//

import Foundation

// MARK: - Output

/// Inline logging target suggestion (distinct from WorkoutPlanView's ProgressionSuggestion).
struct InlineProgressionTarget: Equatable {
    let weight: Double          // stored lb
    let reps: Int
    let rpe: Double?
    let hint: String            // Short human-readable explanation chip
    /// True when the chip nudges a cautious PR attempt (strength block, final week).
    var suggestsPRAttempt: Bool = false
}

// MARK: - Advisor

enum ProgressionAdvisor {

    // MARK: Public

    /// Derive a target for the next set from the exercise's recent history.
    ///
    /// - Parameters:
    ///   - exerciseLog: The in-progress log (used to respect current session reps already logged).
    ///   - lastWorkingSets: Working sets from the *previous* session for this exercise (most-recent first).
    ///   - exerciseRole: Compound vs accessory changes the increment strategy.
    ///   - consecutiveMissed: Number of consecutive scheduled sessions skipped before today.
    ///   - blockContext: When set (dynamic program), scales targets with block volume and deload flags.
    static func suggest(
        for exerciseLog: ExerciseLog,
        lastWorkingSets: [LoggedSet],
        exerciseRole: ExerciseRole = .accessory,
        consecutiveMissed: Int = 0,
        blockContext: BlockContext? = nil
    ) -> InlineProgressionTarget? {
        let lastWorking = lastWorkingSets.filter { $0.countsTowardLoadPRMetrics }
        guard !lastWorking.isEmpty else { return nil }

        let lastWeight = lastWorking.first?.weight ?? 0
        let lastReps   = lastWorking.first?.reps ?? 0
        guard lastWeight > 0 else { return nil }

        // Deload after ≥2 missed sessions
        if consecutiveMissed >= 2 {
            let deloadWeight = (lastWeight * 0.9).roundedToNearestStep(5)
            return applyBlockPolicy(
                InlineProgressionTarget(
                    weight: deloadWeight,
                    reps: lastReps,
                    rpe: 7,
                    hint: "Deload – missed \(consecutiveMissed) sessions",
                    suggestsPRAttempt: false
                ),
                blockContext: blockContext,
                lastBaselineWeight: lastWeight
            )
        }

        switch exerciseRole {
        case .compound:
            let band = compoundRepBand(for: blockContext?.focus.kind)
            let clampedReps = min(max(lastReps, band.lowerBound), band.upperBound)
            let prAttempt = shouldSuggestPRAttempt(blockContext: blockContext)
            let baseLinear = (lastWeight + 5).roundedToNearestStep(5)
            let suggestedWeight = prAttempt ? (baseLinear + 5).roundedToNearestStep(5) : baseLinear
            let hintBase = prAttempt ? "PR week — top set attempt (+10 lb vs last)" : "Linear +5 lb"
            return applyBlockPolicy(
                InlineProgressionTarget(
                    weight: suggestedWeight,
                    reps: clampedReps,
                    rpe: prAttempt ? 9 : 8,
                    hint: hintBase,
                    suggestsPRAttempt: prAttempt
                ),
                blockContext: blockContext,
                lastBaselineWeight: lastWeight
            )

        default:
            // Double-progression: push reps to the top of the target range first,
            // then bump weight and reset to bottom of the range.
            let repsRange = adjustedAccessoryRepRange(
                base: exerciseLog.recommendedRepsRange(),
                focusKind: blockContext?.focus.kind
            )
            let targetRepsTop = repsRange.upperBound
            let targetRepsBottom = repsRange.lowerBound

            // If all last sets hit or exceeded the rep ceiling, add weight
            let allHitCeiling = lastWorking.allSatisfy { $0.reps >= targetRepsTop }
            if allHitCeiling {
                let suggestedWeight = (lastWeight + 5).roundedToNearestStep(5)
                return applyBlockPolicy(
                    InlineProgressionTarget(
                        weight: suggestedWeight,
                        reps: targetRepsBottom,
                        rpe: 8,
                        hint: "Rep ceiling hit — +5 lb, drop reps",
                        suggestsPRAttempt: false
                    ),
                    blockContext: blockContext,
                    lastBaselineWeight: lastWeight
                )
            } else {
                // Same weight, push for +1 rep
                return applyBlockPolicy(
                    InlineProgressionTarget(
                        weight: lastWeight,
                        reps: min(lastReps + 1, targetRepsTop),
                        rpe: 8,
                        hint: "Double progression — +1 rep",
                        suggestsPRAttempt: false
                    ),
                    blockContext: blockContext,
                    lastBaselineWeight: lastWeight
                )
            }
        }
    }

    private static func applyBlockPolicy(
        _ target: InlineProgressionTarget,
        blockContext: BlockContext?,
        lastBaselineWeight: Double
    ) -> InlineProgressionTarget {
        guard let ctx = blockContext else { return target }
        let vol = max(0.45, min(1.25, ctx.volumeMultiplier))
        var weight = (target.weight * vol).roundedToNearestStep(5)
        if ctx.isDeloadBlock {
            weight = min(weight, (lastBaselineWeight * 0.92).roundedToNearestStep(5))
        }
        let tag = ctx.isDeloadBlock ? " · Deload block" : " · \(ctx.focus.displayTitle)"
        return InlineProgressionTarget(
            weight: max(0, weight),
            reps: target.reps,
            rpe: target.rpe,
            hint: target.hint + tag,
            suggestsPRAttempt: target.suggestsPRAttempt
        )
    }

    private static func compoundRepBand(for focusKind: BlockFocusKind?) -> ClosedRange<Int> {
        switch focusKind {
        case .strength: return 3 ... 6
        case .power: return 2 ... 5
        case .endurance, .hybrid: return 10 ... 18
        case .deload: return 6 ... 10
        case .hypertrophy, .general, .none: return 5 ... 10
        }
    }

    private static func adjustedAccessoryRepRange(base: ClosedRange<Int>, focusKind: BlockFocusKind?) -> ClosedRange<Int> {
        guard let k = focusKind else { return base }
        switch k {
        case .strength:
            return max(base.lowerBound, 3) ... min(max(base.upperBound, 5), 8)
        case .hypertrophy, .general:
            return max(base.lowerBound, 6) ... max(base.upperBound, 12)
        case .endurance, .hybrid:
            return max(base.lowerBound, 12) ... max(base.upperBound, 22)
        case .power:
            return max(base.lowerBound, 2) ... min(max(base.upperBound, 6), 8)
        case .deload:
            return max(6, base.lowerBound) ... min(15, base.upperBound)
        }
    }

    private static func shouldSuggestPRAttempt(blockContext: BlockContext?) -> Bool {
        guard let ctx = blockContext else { return false }
        guard ctx.focus.kind == .strength, !ctx.isDeloadBlock else { return false }
        let lastWeekIndex = max(0, ctx.blockDurationWeeks - 1)
        return ctx.weekIndexInBlock == lastWeekIndex
    }

    // MARK: - History helpers

    /// Extracts the last N working sets for a given exercise from completed sessions (most-recent first).
    static func lastWorkingSets(
        forExerciseId id: UUID,
        from completedSessions: [WorkoutSession],
        limit: Int = 5
    ) -> [LoggedSet] {
        completedSessions
            .filter { $0.isCompleted }
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
            .flatMap { $0.exerciseLogs.filter { $0.workoutExercise.exerciseId == id } }
            .flatMap { $0.loggedSets }
            .filter { $0.countsTowardLoadPRMetrics }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Helpers

private extension Double {
    func roundedToNearestStep(_ step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}

private extension ExerciseLog {
    func recommendedRepsRange() -> ClosedRange<Int> {
        let raw = workoutExercise.recommendedReps  // e.g. "8-12"
        let parts = raw.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if parts.count == 2 { return parts[0]...parts[1] }
        if let single = parts.first { return single...single }
        return 8...12
    }
}
