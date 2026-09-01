//
//  LastSessionWorkingRecap.swift
//  FitLog
//
//  Compact last-session load/duration for Home start pickers and Plan day sheets.
//

import Foundation

enum LastSessionWorkingRecap {
    struct Recap: Equatable {
        /// Chip/row line: last working load or cardio duration (e.g. `185 lb × 8` / `45 min`).
        let compactLine: String
        /// Plan/detail line: exercise name plus load when known.
        let detailLine: String
        /// Whole-session elapsed time.
        let durationLine: String
        let endedAt: Date
    }

    static func compactLine(from session: WorkoutSession, weightUnit: WeightDisplayUnit) -> String? {
        make(from: session, weightUnit: weightUnit)?.compactLine
    }

    static func make(from session: WorkoutSession, weightUnit: WeightDisplayUnit) -> Recap? {
        guard let endedAt = session.endTime else { return nil }
        let durationSeconds = max(0, Int(endedAt.timeIntervalSince(session.startTime)))
        let durationLine = durationSeconds > 0
            ? HistoryFormatters.formatAvgDuration(durationSeconds)
            : ""

        if let working = firstWorkingLoad(in: session, weightUnit: weightUnit) {
            let detail = working.exerciseName.isEmpty
                ? working.loadLine
                : "\(working.exerciseName) · \(working.loadLine)"
            return Recap(
                compactLine: working.loadLine,
                detailLine: detail,
                durationLine: durationLine,
                endedAt: endedAt
            )
        }

        if let cardio = firstCardioSummary(in: session) {
            return Recap(
                compactLine: cardio,
                detailLine: cardio,
                durationLine: durationLine,
                endedAt: endedAt
            )
        }

        if session.workout.workoutKind == .cardio || session.workout.workoutKind == .hybrid,
           !durationLine.isEmpty {
            return Recap(
                compactLine: durationLine,
                detailLine: durationLine,
                durationLine: durationLine,
                endedAt: endedAt
            )
        }

        guard !durationLine.isEmpty else { return nil }
        return Recap(
            compactLine: durationLine,
            detailLine: durationLine,
            durationLine: durationLine,
            endedAt: endedAt
        )
    }

    private static func firstWorkingLoad(
        in session: WorkoutSession,
        weightUnit: WeightDisplayUnit
    ) -> (exerciseName: String, loadLine: String)? {
        for log in session.exerciseLogs {
            guard let set = log.loggedSets.last(where: { $0.countsTowardLoadPRMetrics }) else { continue }
            return (exerciseName(for: log), set.weightRepsDisplaySummary(displayUnit: weightUnit))
        }
        return nil
    }

    private static func firstCardioSummary(in session: WorkoutSession) -> String? {
        for log in session.exerciseLogs {
            guard let set = log.loggedSets.last(where: { $0.countsTowardCardioTotals }) else { continue }
            let summary = set.cardioDisplaySummary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty { return summary }
        }
        return nil
    }

    private static func exerciseName(for log: ExerciseLog) -> String {
        if let snap = log.workoutExercise.snapshot {
            let name = snap.nameAtTimeOfLog.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
        }
        let slot = log.workoutExercise.slotLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return slot
    }
}
