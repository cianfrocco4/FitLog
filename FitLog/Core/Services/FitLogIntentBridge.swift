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
        static let sapphireTodaySnapshot = "fitlog.intent.sapphireTodaySnapshot"
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

    /// Last-load / last-cardio / already-trained snapshot for Sapphire Siri actions.
    /// Distinct from rubyRepeatSnapshot, citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct SapphireTodaySnapshot: Codable, Equatable {
        var lastCardioWorkoutName: String?
        var lastCardioCaption: String?
        var trainedToday: Bool
        var trainedTodayWorkoutName: String?
        /// Lowercased workout name → last working-load or last cardio duration caption.
        var lastCaptionByWorkoutName: [String: String]

        init(
            lastCardioWorkoutName: String? = nil,
            lastCardioCaption: String? = nil,
            trainedToday: Bool = false,
            trainedTodayWorkoutName: String? = nil,
            lastCaptionByWorkoutName: [String: String] = [:]
        ) {
            self.lastCardioWorkoutName = lastCardioWorkoutName
            self.lastCardioCaption = lastCardioCaption
            self.trainedToday = trainedToday
            self.trainedTodayWorkoutName = trainedTodayWorkoutName
            self.lastCaptionByWorkoutName = lastCaptionByWorkoutName
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

    static func publishSapphireTodaySnapshot(_ snapshot: SapphireTodaySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.sapphireTodaySnapshot)
    }

    static func loadSapphireTodaySnapshot() -> SapphireTodaySnapshot? {
        guard
            let data = defaults.data(forKey: Key.sapphireTodaySnapshot),
            let snapshot = try? JSONDecoder().decode(SapphireTodaySnapshot.self, from: data)
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
