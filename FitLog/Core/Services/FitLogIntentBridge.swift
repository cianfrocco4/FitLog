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
        static let pendingSkipRemainingSets = "fitlog.intent.pendingSkipRemainingSets"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let moonstoneSessionSnapshot = "fitlog.intent.moonstoneSessionSnapshot"
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

    /// In-progress snapshot for Moonstone Siri skip-remaining / next-set / ready-to-finish.
    /// Distinct from tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot, lapisHistorySnapshot,
    /// peridotFinishSnapshot, onyxNextPlanSnapshot, garnetLibrarySnapshot,
    /// amethystTomorrowSnapshot, emeraldStrengthSnapshot, sapphireTodaySnapshot,
    /// rubyRepeatSnapshot, citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct MoonstoneSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var skipExerciseName: String?
        var skipCaption: String?
        var nextAfterSkipName: String?
        var nextAfterSkipCaption: String?
        var canSkipRemaining: Bool
        var nextSetExerciseName: String?
        var nextSetNumber: Int
        var nextSetOf: Int
        var nextSetLastCaption: String?
        var isCardioNextSet: Bool
        var remainingIncompleteCount: Int
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            skipExerciseName: String? = nil,
            skipCaption: String? = nil,
            nextAfterSkipName: String? = nil,
            nextAfterSkipCaption: String? = nil,
            canSkipRemaining: Bool = false,
            nextSetExerciseName: String? = nil,
            nextSetNumber: Int = 0,
            nextSetOf: Int = 0,
            nextSetLastCaption: String? = nil,
            isCardioNextSet: Bool = false,
            remainingIncompleteCount: Int = 0,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.skipExerciseName = skipExerciseName
            self.skipCaption = skipCaption
            self.nextAfterSkipName = nextAfterSkipName
            self.nextAfterSkipCaption = nextAfterSkipCaption
            self.canSkipRemaining = canSkipRemaining
            self.nextSetExerciseName = nextSetExerciseName
            self.nextSetNumber = nextSetNumber
            self.nextSetOf = nextSetOf
            self.nextSetLastCaption = nextSetLastCaption
            self.isCardioNextSet = isCardioNextSet
            self.remainingIncompleteCount = remainingIncompleteCount
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

    static func queueSkipRemainingSets() {
        defaults.set(true, forKey: Key.pendingSkipRemainingSets)
    }

    static func publishMoonstoneSessionSnapshot(_ snapshot: MoonstoneSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.moonstoneSessionSnapshot)
    }

    static func loadMoonstoneSessionSnapshot() -> MoonstoneSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.moonstoneSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(MoonstoneSessionSnapshot.self, from: data)
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

    static func consumePendingSkipRemainingSets() -> Bool {
        guard defaults.object(forKey: Key.pendingSkipRemainingSets) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingSkipRemainingSets)
        defaults.removeObject(forKey: Key.pendingSkipRemainingSets)
        return queued
    }
}
