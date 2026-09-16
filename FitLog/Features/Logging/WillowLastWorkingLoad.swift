//
//  WillowLastWorkingLoad.swift
//  FitLog
//
//  Last working load / last cardio duration for program slot editing,
//  day-pager rows, and import-rotation workout pickers.
//

import Foundation

enum WillowLastWorkingLoad {
    struct LastStrengthFill: Equatable {
        let workingSetCount: Int
        let reps: Int
        let restSeconds: Int
        let caption: String

        var repsText: String { "\(reps)" }
    }

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

    /// Caption for a library workout: matching completed session first, else first exercise with history.
    static func caption(
        forWorkout workout: Workout,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> String? {
        let completed = completedNewestFirst(sessions)
        if let session = completed.first(where: { $0.workout.id == workout.id }) {
            for log in session.exerciseLogs {
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    return caption
                }
            }
        }
        for row in workout.exercises {
            guard let id = row.exerciseId else { continue }
            if let caption = caption(for: id, from: sessions, displayUnit: displayUnit) {
                return caption
            }
        }
        return nil
    }

    static func lastStrengthFill(
        for exerciseId: UUID,
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> LastStrengthFill? {
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                let working = log.loggedSets.filter(\.countsTowardLoadPRMetrics)
                guard let first = working.first else { continue }
                return LastStrengthFill(
                    workingSetCount: working.count,
                    reps: first.reps,
                    restSeconds: first.restTime,
                    caption: "Last \(first.weightRepsDisplaySummary(displayUnit: displayUnit))"
                )
            }
        }
        return nil
    }

    static func applying(_ fill: LastStrengthFill, to slot: SplitBuilderEditableSlot) -> SplitBuilderEditableSlot {
        var next = slot
        next.sets = max(1, min(20, fill.workingSetCount))
        next.reps = fill.repsText
        next.restSeconds = fill.restSeconds
        return next
    }

    static func slotMatchesLastStrength(_ slot: SplitBuilderEditableSlot, fill: LastStrengthFill) -> Bool {
        slot.sets == max(1, min(20, fill.workingSetCount))
            && slot.reps == fill.repsText
            && (slot.restSeconds ?? 90) == fill.restSeconds
    }

    // MARK: - Private

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
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
