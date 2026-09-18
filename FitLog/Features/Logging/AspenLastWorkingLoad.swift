//
//  AspenLastWorkingLoad.swift
//  FitLog
//
//  Last working load / last cardio duration for the plan add-exercise picker,
//  exercise library, and AI/offline plan suggestions.
//

import Foundation

enum AspenLastWorkingLoad {
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

    static func lastCardioDurationSec(
        for exerciseId: UUID,
        from sessions: [WorkoutSession]
    ) -> Int? {
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs where log.workoutExercise.exerciseId == exerciseId {
                if let sec = lastCardioDurationSec(in: log) {
                    return sec
                }
            }
        }
        return nil
    }

    static func applyingLastDuration(_ seconds: Int, to prescription: CardioPrescription) -> CardioPrescription {
        var next = prescription
        next.targetDurationSec = max(1, seconds)
        return next
    }

    static func defaultPrescription(for exercise: Exercise) -> CardioPrescription {
        let metric = exercise.cardioMetadata?.primaryMetric ?? .time
        switch metric {
        case .distance:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 20 * 60, targetDistanceM: 3_000)
        case .calories:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 15 * 60)
        case .time, .strokes, .steps, .laps:
            return CardioPrescription(kind: .steadyState, targetDurationSec: 30 * 60, targetZone: .zone2)
        }
    }

    static func prescriptionFillingLastDuration(
        for exercise: Exercise,
        from sessions: [WorkoutSession]
    ) -> CardioPrescription {
        var rx = defaultPrescription(for: exercise)
        if let sec = lastCardioDurationSec(for: exercise.id, from: sessions) {
            rx = applyingLastDuration(sec, to: rx)
        }
        return rx
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
