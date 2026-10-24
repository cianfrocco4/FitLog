//
//  TopazLastWorkingLoad.swift
//  FitLog
//
//  Last saved library workout + last working load (skips warm-ups) / last
//  cardio duration for Siri and Shortcuts. Lets “Start Workout” with no name
//  repeat yesterday without a Home round trip.
//

import Foundation

enum TopazLastWorkingLoad {
    static let noSavedWorkoutDialog =
        "No saved workout to start. Open Workout Log AI to create one."

    /// Prefer the most recently completed library workout, then a session name
    /// that still exists in the library, then the first library workout.
    static func lastSavedWorkoutSnapshot(
        library: [Workout],
        sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> FitLogIntentBridge.LastSavedWorkoutSnapshot? {
        let captions = captionsByExerciseId(from: sessions, displayUnit: displayUnit)
        let newest = newestCompletedCaption(from: sessions, displayUnit: displayUnit)

        let names = captionsByExerciseName(from: sessions, displayUnit: displayUnit)

        if let workout = mostRecentCompletedLibraryWorkout(library: library, sessions: sessions) {
            return snapshot(for: workout, captions: captions, names: names, fallbackCaption: newest)
        }

        if let workout = newestCompletedSessionMatchingLibrary(library: library, sessions: sessions) {
            return snapshot(for: workout, captions: captions, names: names, fallbackCaption: newest)
        }

        if let workout = library.first(where: { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return snapshot(for: workout, captions: captions, names: names, fallbackCaption: newest)
        }

        return nil
    }

    /// Named request wins; otherwise use the published last saved workout.
    static func resolvedStartWorkoutName(
        requested: String?,
        snapshot: FitLogIntentBridge.LastSavedWorkoutSnapshot?
    ) -> String? {
        let trimmed = requested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        let saved = snapshot?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? nil : saved
    }

    /// Show last-load only when Siri is starting the saved last workout (or no name was given).
    static func startLastLoadCaption(
        requested: String?,
        snapshot: FitLogIntentBridge.LastSavedWorkoutSnapshot?
    ) -> String? {
        if let requested = requested?.trimmingCharacters(in: .whitespacesAndNewlines),
           !requested.isEmpty,
           snapshot?.name.localizedCaseInsensitiveCompare(requested) != .orderedSame {
            return nil
        }
        return snapshot?.lastLoadCaption
    }

    static func startDialog(workoutName: String, lastLoadCaption: String?) -> String {
        let name = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lastLoadCaption, !lastLoadCaption.isEmpty else {
            return "Starting \(name)."
        }
        return "Starting \(name). \(lastLoadCaption)."
    }

    static func queuedLogSetMessage(
        reps: Int,
        weightPounds: Double,
        lastLoadCaption: String?
    ) -> String {
        let queued = "Queued \(reps) reps at \(Int(weightPounds)) lbs"
        if let lastLoadCaption, !lastLoadCaption.isEmpty {
            return "\(queued) — \(lastLoadCaption.lowercased()). Open \(AppBrand.name) to apply"
        }
        return "\(queued) — open \(AppBrand.name) to apply"
    }

    static func lastLoadCaption(
        forExerciseName name: String?,
        snapshot: FitLogIntentBridge.LastSavedWorkoutSnapshot?
    ) -> String? {
        guard let snapshot else { return nil }
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty,
               let match = snapshot.lastLoadByExerciseName.first(where: {
                   $0.key.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
               }) {
                return match.value
            }
        }
        return snapshot.lastLoadCaption
    }

    private static func captionsByExerciseId(
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

    static func newestCompletedCaption(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> String? {
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs {
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    return caption
                }
            }
        }
        return nil
    }

    static func storedDisplayUnit(defaults: UserDefaults = .standard) -> WeightDisplayUnit {
        if let raw = defaults.string(forKey: "fitlog.weightDisplayUnit"),
           let unit = WeightDisplayUnit(rawValue: raw) {
            return unit
        }
        return .pounds
    }

    // MARK: - Private

    private static func snapshot(
        for workout: Workout,
        captions: [UUID: String],
        names: [String: String],
        fallbackCaption: String?
    ) -> FitLogIntentBridge.LastSavedWorkoutSnapshot {
        var byName = names
        for row in workout.exercises {
            guard let id = row.exerciseId, let caption = captions[id] else { continue }
            let name = row.snapshot?.nameAtTimeOfLog ?? row.slotLabel
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                byName[trimmed] = caption
            }
        }
        let workoutCaption = workout.exercises.compactMap { row -> String? in
            guard let id = row.exerciseId else { return nil }
            return captions[id]
        }.first
        return FitLogIntentBridge.LastSavedWorkoutSnapshot(
            name: workout.name,
            lastLoadCaption: workoutCaption ?? fallbackCaption,
            lastLoadByExerciseName: byName
        )
    }

    private static func captionsByExerciseName(
        from sessions: [WorkoutSession],
        displayUnit: WeightDisplayUnit
    ) -> [String: String] {
        var result: [String: String] = [:]
        for session in completedNewestFirst(sessions) {
            for log in session.exerciseLogs {
                let name = log.workoutExercise.snapshot?.nameAtTimeOfLog
                    ?? log.workoutExercise.slotLabel
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, result[trimmed] == nil else { continue }
                if let caption = caption(from: log, displayUnit: displayUnit) {
                    result[trimmed] = caption
                }
            }
        }
        return result
    }

    private static func mostRecentCompletedLibraryWorkout(
        library: [Workout],
        sessions: [WorkoutSession]
    ) -> Workout? {
        let byId = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
        var seen = Set<UUID>()
        for session in completedNewestFirst(sessions) {
            guard let id = session.sessionPlanOrigin?.libraryWorkoutId,
                  seen.insert(id).inserted,
                  let workout = byId[id],
                  !workout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            return workout
        }
        return nil
    }

    private static func newestCompletedSessionMatchingLibrary(
        library: [Workout],
        sessions: [WorkoutSession]
    ) -> Workout? {
        for session in completedNewestFirst(sessions) {
            let name = session.workout.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if let match = library.first(where: {
                $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
            }) {
                return match
            }
        }
        return nil
    }

    private static func completedNewestFirst(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter(\.isCompleted)
            .sorted { ($0.endTime ?? $0.startTime) > ($1.endTime ?? $1.startTime) }
    }

    private static func caption(from log: ExerciseLog, displayUnit: WeightDisplayUnit) -> String? {
        if let working = log.loggedSets.first(where: { $0.countsTowardLoadPRMetrics }) {
            return "Last \(working.weightRepsDisplaySummary(displayUnit: displayUnit))"
        }
        if let sec = log.loggedSets.first(where: {
            $0.countsTowardCardioTotals && ($0.cardioMetrics?.durationSec ?? 0) > 0
        })?.cardioMetrics?.durationSec {
            return "Last \(CardioMetricsCalculator.formatDuration(seconds: sec))"
        }
        return nil
    }
}
