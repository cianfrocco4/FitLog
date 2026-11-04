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
        static let pendingRepeatLastSet = "fitlog.intent.pendingRepeatLastSet"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let jasperSessionSnapshot = "fitlog.intent.jasperSessionSnapshot"
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

    /// In-progress snapshot for Jasper Siri repeat-last-set / remaining / next-exercise.
    /// Distinct from lapisHistorySnapshot, peridotFinishSnapshot, onyxNextPlanSnapshot,
    /// garnetLibrarySnapshot, amethystTomorrowSnapshot, emeraldStrengthSnapshot,
    /// sapphireTodaySnapshot, rubyRepeatSnapshot, citrineLastLoadSnapshot, and
    /// topaz LastSavedWorkoutSnapshot.
    struct JasperSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var lastRepeatableExerciseName: String?
        var lastRepeatableCaption: String?
        var remainingSetCount: Int
        var remainingExerciseCount: Int
        var nextExerciseName: String?
        var nextExerciseRemainingSets: Int
        var nextExerciseCaption: String?

        init(
            inProgressWorkoutName: String? = nil,
            lastRepeatableExerciseName: String? = nil,
            lastRepeatableCaption: String? = nil,
            remainingSetCount: Int = 0,
            remainingExerciseCount: Int = 0,
            nextExerciseName: String? = nil,
            nextExerciseRemainingSets: Int = 0,
            nextExerciseCaption: String? = nil
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.lastRepeatableExerciseName = lastRepeatableExerciseName
            self.lastRepeatableCaption = lastRepeatableCaption
            self.remainingSetCount = remainingSetCount
            self.remainingExerciseCount = remainingExerciseCount
            self.nextExerciseName = nextExerciseName
            self.nextExerciseRemainingSets = nextExerciseRemainingSets
            self.nextExerciseCaption = nextExerciseCaption
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

    static func queueRepeatLastSet() {
        defaults.set(true, forKey: Key.pendingRepeatLastSet)
    }

    static func publishJasperSessionSnapshot(_ snapshot: JasperSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.jasperSessionSnapshot)
    }

    static func loadJasperSessionSnapshot() -> JasperSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.jasperSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(JasperSessionSnapshot.self, from: data)
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

    static func consumePendingRepeatLastSet() -> Bool {
        guard defaults.object(forKey: Key.pendingRepeatLastSet) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingRepeatLastSet)
        defaults.removeObject(forKey: Key.pendingRepeatLastSet)
        return queued
    }
}
