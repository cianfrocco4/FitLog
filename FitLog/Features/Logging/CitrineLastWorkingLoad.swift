//
//  CitrineLastWorkingLoad.swift
//  FitLog
//
//  Last working load (skips warm-ups) / last cardio duration for Siri query
//  intents and rest-timer confirmation so yesterday is visible without a
//  Home round trip. Distinct from Topaz (Start Workout / Log Set actions).
//

import Foundation

enum CitrineLastWorkingLoad {
    static let noCompletedWorkoutDialog =
        "No completed workout yet. Open Workout Log AI to log one."
    static let noLastLoadDialog =
        "No last working load yet. Open Workout Log AI to log a set."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.LastLoadQuerySnapshot {
        var lastWorkoutName: String?
        var newestCaption: String?
        var lastCardioCaption: String?
        var captionsByExerciseName: [String: String] = [:]

        for session in completedNewestFirst(sessions) {
            if lastWorkoutName == nil {
                let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    lastWorkoutName = name
                }
            }
            for log in session.exerciseLogs {
                guard let caption = caption(from: log, displayUnit: displayUnit) else { continue }
                if newestCaption == nil {
                    newestCaption = caption
                }
                let exerciseName = exerciseName(from: log)
                if !exerciseName.isEmpty, captionsByExerciseName[exerciseName] == nil {
                    captionsByExerciseName[exerciseName] = caption
                }
                if lastCardioCaption == nil, let sec = lastCardioDurationSec(in: log) {
                    lastCardioCaption = "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
                }
            }
        }

        return FitLogIntentBridge.LastLoadQuerySnapshot(
            lastWorkoutName: lastWorkoutName,
            newestCaption: newestCaption,
            lastCardioCaption: lastCardioCaption,
            captionsByExerciseName: captionsByExerciseName
        )
    }

    static func lastWorkoutDialog(
        snapshot: FitLogIntentBridge.LastLoadQuerySnapshot?
    ) -> String {
        guard let name = snapshot?.lastWorkoutName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return noCompletedWorkoutDialog
        }
        if let caption = snapshot?.newestCaption, !caption.isEmpty {
            return "Last workout: \(name). \(caption)."
        }
        return "Last workout: \(name)."
    }

    static func lastLoadDialog(
        exerciseName: String?,
        snapshot: FitLogIntentBridge.LastLoadQuerySnapshot?
    ) -> String {
        let trimmed = exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            if let caption = caption(forExerciseName: trimmed, snapshot: snapshot) {
                return "\(trimmed): \(caption)."
            }
            return "No last working load for \(trimmed)."
        }
        if let caption = snapshot?.newestCaption, !caption.isEmpty {
            if let name = snapshot?.lastWorkoutName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !name.isEmpty {
                return "\(caption) (\(name))."
            }
            return "\(caption)."
        }
        return noLastLoadDialog
    }

    static func restTimerDialog(
        durationSeconds: Int,
        snapshot: FitLogIntentBridge.LastLoadQuerySnapshot?
    ) -> String {
        let seconds = max(1, durationSeconds)
        guard let caption = snapshot?.newestCaption, !caption.isEmpty else {
            return "Resting \(seconds) seconds."
        }
        return "Resting \(seconds) seconds. \(caption)."
    }

    static func caption(
        forExerciseName name: String,
        snapshot: FitLogIntentBridge.LastLoadQuerySnapshot?
    ) -> String? {
        guard let snapshot else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let match = snapshot.captionsByExerciseName.first(where: {
            $0.key.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return match.value
        }
        return nil
    }

    /// Newest completed session's first working load or cardio duration (any exercise).
    static func newestCompletedCaption(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> String? {
        querySnapshot(from: sessions, displayUnit: displayUnit).newestCaption
    }

    static func lastCardioDurationCaption(from sessions: [WorkoutSession]) -> String? {
        querySnapshot(from: sessions, displayUnit: .pounds).lastCardioCaption
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func exerciseName(from log: ExerciseLog) -> String {
        let raw = log.workoutExercise.snapshot?.nameAtTimeOfLog
            ?? log.workoutExercise.slotLabel
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
