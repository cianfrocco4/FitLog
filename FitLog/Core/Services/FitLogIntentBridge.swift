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
        static let pendingFocusPreviousExercise = "fitlog.intent.pendingFocusPreviousExercise"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let spinelSessionSnapshot = "fitlog.intent.spinelSessionSnapshot"
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

    /// In-progress snapshot for Spinel Siri go-to-previous / previous-exercise /
    /// this-exercise-sets. Distinct from alexandriteSessionSnapshot,
    /// moonstoneSessionSnapshot, tanzaniteSessionSnapshot,
    /// aquamarineSessionSnapshot, tourmalineSessionSnapshot,
    /// jasperSessionSnapshot, lapisHistorySnapshot, peridotFinishSnapshot,
    /// onyxNextPlanSnapshot, garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct SpinelSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedCaption: String?
        var focusedIsIncomplete: Bool
        var focusedIsCardio: Bool
        var focusedWorkingSetsLogged: Int
        var focusedRecommendedSets: Int
        var previousExerciseName: String?
        var previousExerciseCaption: String?
        var canFocusPrevious: Bool
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedCaption: String? = nil,
            focusedIsIncomplete: Bool = false,
            focusedIsCardio: Bool = false,
            focusedWorkingSetsLogged: Int = 0,
            focusedRecommendedSets: Int = 0,
            previousExerciseName: String? = nil,
            previousExerciseCaption: String? = nil,
            canFocusPrevious: Bool = false,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedCaption = focusedCaption
            self.focusedIsIncomplete = focusedIsIncomplete
            self.focusedIsCardio = focusedIsCardio
            self.focusedWorkingSetsLogged = focusedWorkingSetsLogged
            self.focusedRecommendedSets = focusedRecommendedSets
            self.previousExerciseName = previousExerciseName
            self.previousExerciseCaption = previousExerciseCaption
            self.canFocusPrevious = canFocusPrevious
            self.hasOpenPlaceholder = hasOpenPlaceholder
            self.isReadyToFinish = isReadyToFinish
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

    static func queueFocusPreviousExercise() {
        defaults.set(true, forKey: Key.pendingFocusPreviousExercise)
    }

    static func publishSpinelSessionSnapshot(_ snapshot: SpinelSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.spinelSessionSnapshot)
    }

    static func loadSpinelSessionSnapshot() -> SpinelSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.spinelSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(SpinelSessionSnapshot.self, from: data)
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

    static func consumePendingFocusPreviousExercise() -> Bool {
        guard defaults.object(forKey: Key.pendingFocusPreviousExercise) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingFocusPreviousExercise)
        defaults.removeObject(forKey: Key.pendingFocusPreviousExercise)
        return queued
    }
}
