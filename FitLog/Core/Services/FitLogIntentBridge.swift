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
        static let pendingUndoLastSet = "fitlog.intent.pendingUndoLastSet"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let tanzaniteSessionSnapshot = "fitlog.intent.tanzaniteSessionSnapshot"
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

    /// In-progress snapshot for Tanzanite Siri undo-last-set / sets-logged / elapsed.
    /// Distinct from aquamarineSessionSnapshot, tourmalineSessionSnapshot,
    /// jasperSessionSnapshot, lapisHistorySnapshot, peridotFinishSnapshot,
    /// onyxNextPlanSnapshot, garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct TanzaniteSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var undoExerciseName: String?
        var undoCaption: String?
        var canUndoLastSet: Bool
        var loggedSetCount: Int
        var workingSetCount: Int
        var startTimeEpoch: TimeInterval?

        var startTime: Date? {
            startTimeEpoch.map { Date(timeIntervalSince1970: $0) }
        }

        init(
            inProgressWorkoutName: String? = nil,
            undoExerciseName: String? = nil,
            undoCaption: String? = nil,
            canUndoLastSet: Bool = false,
            loggedSetCount: Int = 0,
            workingSetCount: Int = 0,
            startTimeEpoch: TimeInterval? = nil
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.undoExerciseName = undoExerciseName
            self.undoCaption = undoCaption
            self.canUndoLastSet = canUndoLastSet
            self.loggedSetCount = loggedSetCount
            self.workingSetCount = workingSetCount
            self.startTimeEpoch = startTimeEpoch
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

    static func queueUndoLastSet() {
        defaults.set(true, forKey: Key.pendingUndoLastSet)
    }

    static func publishTanzaniteSessionSnapshot(_ snapshot: TanzaniteSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.tanzaniteSessionSnapshot)
    }

    static func loadTanzaniteSessionSnapshot() -> TanzaniteSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.tanzaniteSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(TanzaniteSessionSnapshot.self, from: data)
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

    static func consumePendingUndoLastSet() -> Bool {
        guard defaults.object(forKey: Key.pendingUndoLastSet) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUndoLastSet)
        defaults.removeObject(forKey: Key.pendingUndoLastSet)
        return queued
    }
}
