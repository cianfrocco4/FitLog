//
//  GarnetAskFitLog.swift
//  FitLog
//
//  Start the next *different* saved library workout, a read-only next-saved
//  query, and a saved-workout list so rotating past a single Push A skips a
//  Home or History round trip. Distinct from Amethyst (tomorrow's plan /
//  last-session duration), Emerald (last strength / this-week count),
//  Sapphire (today's plan / last cardio / did-I-train), Ruby (Repeat
//  Yesterday + Readiness / Today's Workout queries), Citrine (Last
//  Workout / Last Weight queries), and Topaz (unnamed Start of last
//  saved library workout). Does not change freemium rules.
//

import Foundation

enum GarnetAskFitLog {
    static let noSavedWorkoutDialog = "No saved workout yet."

    static func querySnapshot(
        from sessions: [WorkoutSession],
        savedWorkoutNames: [String],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.GarnetLibrarySnapshot {
        let names = savedWorkoutNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var lastCaptionByWorkoutName: [String: String] = [:]
        var lastCompletedWorkoutName: String?

        for session in completedNewestFirst(sessions) {
            let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if lastCompletedWorkoutName == nil, !name.isEmpty {
                lastCompletedWorkoutName = name
            }

            let key = workoutNameKey(name)
            if lastCaptionByWorkoutName[key] == nil,
               let caption = sessionCaption(from: session, displayUnit: displayUnit),
               !key.isEmpty {
                lastCaptionByWorkoutName[key] = caption
            }
        }

        return FitLogIntentBridge.GarnetLibrarySnapshot(
            savedWorkoutNames: names,
            lastCompletedWorkoutName: lastCompletedWorkoutName,
            lastCaptionByWorkoutName: lastCaptionByWorkoutName
        )
    }

    static func nextSavedWorkoutName(
        snapshot: FitLogIntentBridge.GarnetLibrarySnapshot?
    ) -> String? {
        let names = snapshot?.savedWorkoutNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        guard !names.isEmpty else { return nil }

        let lastKey = workoutNameKey(snapshot?.lastCompletedWorkoutName ?? "")
        guard !lastKey.isEmpty else { return names[0] }

        if let idx = names.firstIndex(where: { workoutNameKey($0) == lastKey }) {
            for offset in 1...names.count {
                let candidate = names[(idx + offset) % names.count]
                if workoutNameKey(candidate) != lastKey {
                    return candidate
                }
            }
            return names[idx]
        }

        return names[0]
    }

    static func isStartableSavedWorkout(
        snapshot: FitLogIntentBridge.GarnetLibrarySnapshot?
    ) -> Bool {
        nextSavedWorkoutName(snapshot: snapshot) != nil
    }

    static func startNextSavedWorkoutDialog(
        snapshot: FitLogIntentBridge.GarnetLibrarySnapshot?
    ) -> String {
        guard let name = nextSavedWorkoutName(snapshot: snapshot) else {
            return noSavedWorkoutDialog
        }
        if let caption = lastCaption(forWorkoutName: name, snapshot: snapshot) {
            return "Starting \(name). \(caption)."
        }
        return "Starting \(name)."
    }

    static func nextSavedWorkoutDialog(
        snapshot: FitLogIntentBridge.GarnetLibrarySnapshot?
    ) -> String {
        guard let name = nextSavedWorkoutName(snapshot: snapshot) else {
            return noSavedWorkoutDialog
        }
        if let caption = lastCaption(forWorkoutName: name, snapshot: snapshot) {
            return "Next saved workout is \(name). \(caption)."
        }
        return "Next saved workout is \(name)."
    }

    static func savedWorkoutsDialog(
        snapshot: FitLogIntentBridge.GarnetLibrarySnapshot?
    ) -> String {
        let names = snapshot?.savedWorkoutNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        guard !names.isEmpty else { return noSavedWorkoutDialog }
        return "Saved workouts: \(names.joined(separator: ", "))."
    }

    static func lastCaption(
        forWorkoutName name: String,
        snapshot: FitLogIntentBridge.GarnetLibrarySnapshot?
    ) -> String? {
        let key = workoutNameKey(name)
        guard !key.isEmpty, let caption = snapshot?.lastCaptionByWorkoutName[key], !caption.isEmpty else {
            return nil
        }
        return caption
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    static func workoutNameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Private

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func sessionCaption(
        from session: WorkoutSession,
        displayUnit: WeightDisplayUnit
    ) -> String? {
        for log in session.exerciseLogs {
            if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
                return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
            }
            if let sec = lastCardioDurationSec(in: log) {
                return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
            }
        }
        return nil
    }

    private static func lastCardioDurationSec(in log: ExerciseLog) -> Int? {
        log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec
    }
}
