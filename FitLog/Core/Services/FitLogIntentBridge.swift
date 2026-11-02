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
        static let pendingFinishWorkout = "fitlog.intent.pendingFinishWorkout"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let peridotFinishSnapshot = "fitlog.intent.peridotFinishSnapshot"
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

    /// In-progress + last-finished snapshot for Peridot Siri finish actions.
    /// Distinct from onyxNextPlanSnapshot, garnetLibrarySnapshot,
    /// amethystTomorrowSnapshot, emeraldStrengthSnapshot, sapphireTodaySnapshot,
    /// rubyRepeatSnapshot, citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct PeridotFinishSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var inProgressLoggedSetCount: Int
        var inProgressCaption: String?
        var lastFinishedWorkoutName: String?
        var lastFinishedCaption: String?

        init(
            inProgressWorkoutName: String? = nil,
            inProgressLoggedSetCount: Int = 0,
            inProgressCaption: String? = nil,
            lastFinishedWorkoutName: String? = nil,
            lastFinishedCaption: String? = nil
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.inProgressLoggedSetCount = inProgressLoggedSetCount
            self.inProgressCaption = inProgressCaption
            self.lastFinishedWorkoutName = lastFinishedWorkoutName
            self.lastFinishedCaption = lastFinishedCaption
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

    static func queueFinishWorkout() {
        defaults.set(true, forKey: Key.pendingFinishWorkout)
    }

    static func publishPeridotFinishSnapshot(_ snapshot: PeridotFinishSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.peridotFinishSnapshot)
    }

    static func loadPeridotFinishSnapshot() -> PeridotFinishSnapshot? {
        guard
            let data = defaults.data(forKey: Key.peridotFinishSnapshot),
            let snapshot = try? JSONDecoder().decode(PeridotFinishSnapshot.self, from: data)
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

    static func consumePendingFinishWorkout() -> Bool {
        guard defaults.object(forKey: Key.pendingFinishWorkout) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingFinishWorkout)
        defaults.removeObject(forKey: Key.pendingFinishWorkout)
        return queued
    }
}
