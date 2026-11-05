//
//  FitLogIntentBridge.swift
//  FitLog
//
//  Queues Siri / Shortcuts intent actions for the main app to consume on launch.
//

import Foundation

enum FitLogIntentBridge {
    private enum Key {
        static let pendingLogSet = "fitlog.intent.pendingLogSet"
        static let pendingStartWorkoutName = "fitlog.intent.pendingStartWorkoutName"
        static let pendingRestTimerSeconds = "fitlog.intent.pendingRestTimerSeconds"
        static let pendingUseLastCardioDuration = "fitlog.intent.pendingUseLastCardioDuration"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let tourmalineSessionSnapshot = "fitlog.intent.tourmalineSessionSnapshot"
    }

    struct PendingLogSet: Codable, Equatable {
        var exerciseId: UUID?
        var weight: Double
        var reps: Int
        var rpe: Double?
    }

    struct ExerciseSnapshotEntry: Codable, Equatable {
        var id: UUID
        var name: String
    }

    /// In-progress snapshot for Tourmaline Siri use-last-cardio / last-set / current-exercise.
    /// Distinct from jasperSessionSnapshot, lapisHistorySnapshot, peridotFinishSnapshot,
    /// onyxNextPlanSnapshot, garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct TourmalineSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var lastSetExerciseName: String?
        var lastSetCaption: String?
        var currentExerciseName: String?
        var currentExerciseCaption: String?
        var lastCardioExerciseName: String?
        var lastCardioCaption: String?
        var canApplyLastCardio: Bool

        init(
            inProgressWorkoutName: String? = nil,
            lastSetExerciseName: String? = nil,
            lastSetCaption: String? = nil,
            currentExerciseName: String? = nil,
            currentExerciseCaption: String? = nil,
            lastCardioExerciseName: String? = nil,
            lastCardioCaption: String? = nil,
            canApplyLastCardio: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.lastSetExerciseName = lastSetExerciseName
            self.lastSetCaption = lastSetCaption
            self.currentExerciseName = currentExerciseName
            self.currentExerciseCaption = currentExerciseCaption
            self.lastCardioExerciseName = lastCardioExerciseName
            self.lastCardioCaption = lastCardioCaption
            self.canApplyLastCardio = canApplyLastCardio
        }
    }

    private static var defaults: UserDefaults { .standard }

    // MARK: - Queue (called from App Intents)

    static func queueLogSet(_ payload: PendingLogSet) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: Key.pendingLogSet)
    }

    static func queueStartWorkout(named name: String?) {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(name, forKey: Key.pendingStartWorkoutName)
        } else {
            defaults.set("", forKey: Key.pendingStartWorkoutName)
        }
    }

    static func queueRestTimer(seconds: Int) {
        defaults.set(seconds, forKey: Key.pendingRestTimerSeconds)
    }

    static func queueUseLastCardioDuration() {
        defaults.set(true, forKey: Key.pendingUseLastCardioDuration)
    }

    static func publishTourmalineSessionSnapshot(_ snapshot: TourmalineSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.tourmalineSessionSnapshot)
    }

    static func loadTourmalineSessionSnapshot() -> TourmalineSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.tourmalineSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(TourmalineSessionSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    static func publishExerciseLibrary(_ exercises: [ExerciseSnapshotEntry]) {
        guard let data = try? JSONEncoder().encode(exercises) else { return }
        defaults.set(data, forKey: Key.exerciseLibrarySnapshot)
    }

    static func loadExerciseLibrary() -> [ExerciseSnapshotEntry] {
        guard
            let data = defaults.data(forKey: Key.exerciseLibrarySnapshot),
            let entries = try? JSONDecoder().decode([ExerciseSnapshotEntry].self, from: data)
        else { return [] }
        return entries
    }

    // MARK: - Consume (called from main app)

    static func consumePendingLogSet() -> PendingLogSet? {
        guard
            let data = defaults.data(forKey: Key.pendingLogSet),
            let payload = try? JSONDecoder().decode(PendingLogSet.self, from: data)
        else { return nil }
        defaults.removeObject(forKey: Key.pendingLogSet)
        return payload
    }

    static func consumePendingStartWorkoutName() -> String? {
        guard defaults.object(forKey: Key.pendingStartWorkoutName) != nil else { return nil }
        let raw = defaults.string(forKey: Key.pendingStartWorkoutName) ?? ""
        defaults.removeObject(forKey: Key.pendingStartWorkoutName)
        return raw
    }

    static func consumePendingRestTimerSeconds() -> Int? {
        guard let value = defaults.object(forKey: Key.pendingRestTimerSeconds) as? Int else { return nil }
        defaults.removeObject(forKey: Key.pendingRestTimerSeconds)
        return value
    }

    static func consumePendingUseLastCardioDuration() -> Bool {
        guard defaults.object(forKey: Key.pendingUseLastCardioDuration) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUseLastCardioDuration)
        defaults.removeObject(forKey: Key.pendingUseLastCardioDuration)
        return queued
    }
}
