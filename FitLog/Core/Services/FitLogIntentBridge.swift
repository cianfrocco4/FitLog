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
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let emeraldStrengthSnapshot = "fitlog.intent.emeraldStrengthSnapshot"
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

    /// Last-strength / this-week snapshot for Emerald Siri actions.
    /// Distinct from sapphireTodaySnapshot, rubyRepeatSnapshot, citrineLastLoadSnapshot,
    /// and topaz LastSavedWorkoutSnapshot.
    struct EmeraldStrengthSnapshot: Codable, Equatable {
        var lastStrengthWorkoutName: String?
        var lastStrengthCaption: String?
        var thisWeekSessionCount: Int
        var thisWeekLastWorkoutName: String?

        init(
            lastStrengthWorkoutName: String? = nil,
            lastStrengthCaption: String? = nil,
            thisWeekSessionCount: Int = 0,
            thisWeekLastWorkoutName: String? = nil
        ) {
            self.lastStrengthWorkoutName = lastStrengthWorkoutName
            self.lastStrengthCaption = lastStrengthCaption
            self.thisWeekSessionCount = thisWeekSessionCount
            self.thisWeekLastWorkoutName = thisWeekLastWorkoutName
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

    static func publishEmeraldStrengthSnapshot(_ snapshot: EmeraldStrengthSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.emeraldStrengthSnapshot)
    }

    static func loadEmeraldStrengthSnapshot() -> EmeraldStrengthSnapshot? {
        guard
            let data = defaults.data(forKey: Key.emeraldStrengthSnapshot),
            let snapshot = try? JSONDecoder().decode(EmeraldStrengthSnapshot.self, from: data)
        else { return nil }
        return snapshot
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
}
