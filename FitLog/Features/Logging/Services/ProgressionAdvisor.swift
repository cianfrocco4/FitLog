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
    static func suggest(
        for exerciseLog: ExerciseLog,
        lastWorkingSets: [LoggedSet],
        exerciseRole: ExerciseRole = .accessory,
        consecutiveMissed: Int = 0
    ) -> InlineProgressionTarget? {
        let lastWorking = lastWorkingSets.filter { $0.countsTowardLoadPRMetrics }
        guard !lastWorking.isEmpty else { return nil }

        let lastWeight = lastWorking.first?.weight ?? 0
        let lastReps   = lastWorking.first?.reps ?? 0
        guard lastWeight > 0 else { return nil }

        // Deload after ≥2 missed sessions
        if consecutiveMissed >= 2 {
            let deloadWeight = (lastWeight * 0.9).roundedToNearestStep(5)
            return InlineProgressionTarget(
                weight: deloadWeight,
                reps: lastReps,
                rpe: 7,
                hint: "Deload – missed \(consecutiveMissed) sessions"
            )
        }

        switch exerciseRole {
        case .compound:
            // Linear: +5 lb per session (barbell compound movements)
            let suggestedWeight = (lastWeight + 5).roundedToNearestStep(5)
            return InlineProgressionTarget(
                weight: suggestedWeight,
                reps: lastReps,
                rpe: 8,
                hint: "Linear +5 lb"
            )

        default:
            // Double-progression: push reps to the top of the target range first,
            // then bump weight and reset to bottom of the range.
            let repsRange = exerciseLog.recommendedRepsRange()
            let targetRepsTop = repsRange.upperBound
            let targetRepsBottom = repsRange.lowerBound

            // If all last sets hit or exceeded the rep ceiling, add weight
            let allHitCeiling = lastWorking.allSatisfy { $0.reps >= targetRepsTop }
            if allHitCeiling {
                let suggestedWeight = (lastWeight + 5).roundedToNearestStep(5)
                return InlineProgressionTarget(
                    weight: suggestedWeight,
                    reps: targetRepsBottom,
                    rpe: 8,
                    hint: "Rep ceiling hit — +5 lb, drop reps"
                )
            } else {
                // Same weight, push for +1 rep
                return InlineProgressionTarget(
                    weight: lastWeight,
                    reps: min(lastReps + 1, targetRepsTop),
                    rpe: 8,
                    hint: "Double progression — +1 rep"
                )
            }
        }
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
