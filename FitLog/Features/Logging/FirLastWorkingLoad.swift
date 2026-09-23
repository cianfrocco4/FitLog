//
//  FirLastWorkingLoad.swift
//  FitLog
//
//  Last working load / last cardio duration for in-session logging chrome:
//  plate calculator, focused-exercise actions, and session compact header.
//

import Foundation

enum FirLastWorkingLoad {
    /// Newest completed session wins. Strength working sets beat cardio on the same log.
    static func captionsByExerciseId(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs {
                guard let id = log.workoutExercise.exerciseId, result[id] == nil else { continue }
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    result[id] = caption
                }
            }
        }
        return result
    }

    static func caption(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> String? {
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    return caption
                }
            }
        }
        return nil
    }

    static func caption(
        for workoutExercise: WorkoutExercise,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> String? {
        guard let id = workoutExercise.exerciseId else { return nil }
        return caption(for: id, from: sessions, displayUnit: displayUnit)
    }

    static func caption(
        for log: ExerciseLog,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> String? {
        caption(for: log.workoutExercise, from: sessions, displayUnit: displayUnit)
    }

    /// Last working-set weight in the user's display unit, skipping warm-ups.
    /// Nil for cardio-only history or unresolved slots.
    static func lastWorkingDisplayWeight(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> Double? {
        guard let set = lastWorkingSet(for: exerciseId, from: sessions) else { return nil }
        return WeightStoreConversion.displayValue(storedPounds: set.weight, unit: displayUnit)
    }

    static func lastWorkingDisplayWeight(
        for workoutExercise: WorkoutExercise,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> Double? {
        guard let id = workoutExercise.exerciseId else { return nil }
        return lastWorkingDisplayWeight(for: id, from: sessions, displayUnit: displayUnit)
    }

    static func lastWorkingDisplayWeight(
        for log: ExerciseLog,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> Double? {
        lastWorkingDisplayWeight(for: log.workoutExercise, from: sessions, displayUnit: displayUnit)
    }

    // MARK: - Private

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func lastWorkingSet(
        for exerciseId: UUID,
        from sessions: [WorkoutSession]
    ) -> LoggedSet? {
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
                    return working
                }
            }
        }
        return nil
    }

    private static func caption(from log: ExerciseLog, displayUnit: WeightDisplayUnit) -> String? {
        if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
            return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
        }
        if let sec = lastCardioDurationSec(in: log) {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        return nil
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
