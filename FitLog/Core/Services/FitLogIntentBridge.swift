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
        static let pendingFocusNextExercise = "fitlog.intent.pendingFocusNextExercise"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let alexandriteSessionSnapshot = "fitlog.intent.alexandriteSessionSnapshot"
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

    /// In-progress snapshot for Alexandrite Siri go-to-next / remaining /
    /// current-workout. Distinct from moonstoneSessionSnapshot,
    /// tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot, lapisHistorySnapshot,
    /// peridotFinishSnapshot, onyxNextPlanSnapshot, garnetLibrarySnapshot,
    /// amethystTomorrowSnapshot, emeraldStrengthSnapshot, sapphireTodaySnapshot,
    /// rubyRepeatSnapshot, citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct AlexandriteSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedCaption: String?
        var focusedIsIncomplete: Bool
        var nextExerciseName: String?
        var nextExerciseCaption: String?
        var canFocusNext: Bool
        var remainingExerciseNames: [String]
        var remainingCount: Int
        var firstRemainingCaption: String?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedCaption: String? = nil,
            focusedIsIncomplete: Bool = false,
            nextExerciseName: String? = nil,
            nextExerciseCaption: String? = nil,
            canFocusNext: Bool = false,
            remainingExerciseNames: [String] = [],
            remainingCount: Int = 0,
            firstRemainingCaption: String? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedCaption = focusedCaption
            self.focusedIsIncomplete = focusedIsIncomplete
            self.nextExerciseName = nextExerciseName
            self.nextExerciseCaption = nextExerciseCaption
            self.canFocusNext = canFocusNext
            self.remainingExerciseNames = remainingExerciseNames
            self.remainingCount = remainingCount
            self.firstRemainingCaption = firstRemainingCaption
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

    static func queueFocusNextExercise() {
        defaults.set(true, forKey: Key.pendingFocusNextExercise)
    }

    static func publishAlexandriteSessionSnapshot(_ snapshot: AlexandriteSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.alexandriteSessionSnapshot)
    }

    static func loadAlexandriteSessionSnapshot() -> AlexandriteSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.alexandriteSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(AlexandriteSessionSnapshot.self, from: data)
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

    static func consumePendingFocusNextExercise() -> Bool {
        guard defaults.object(forKey: Key.pendingFocusNextExercise) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingFocusNextExercise)
        defaults.removeObject(forKey: Key.pendingFocusNextExercise)
        return queued
    }
}
