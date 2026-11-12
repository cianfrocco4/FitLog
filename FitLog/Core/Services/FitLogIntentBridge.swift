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
        static let pendingSubtractRestTime = "fitlog.intent.pendingSubtractRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let obsidianSessionSnapshot = "fitlog.intent.obsidianSessionSnapshot"
        static let obsidianRestEndsAt = "fitlog.intent.obsidianRestEndsAt"
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

    /// In-progress snapshot for Obsidian Siri subtract-rest / next-exercise-target /
    /// next-exercise-last-working. Distinct from zirconSessionSnapshot,
    /// spinelSessionSnapshot, alexandriteSessionSnapshot,
    /// moonstoneSessionSnapshot, tanzaniteSessionSnapshot,
    /// aquamarineSessionSnapshot, tourmalineSessionSnapshot,
    /// jasperSessionSnapshot, lapisHistorySnapshot,
    /// peridotFinishSnapshot, onyxNextPlanSnapshot,
    /// garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot,
    /// rubyRepeatSnapshot, citrineLastLoadSnapshot, and topaz
    /// LastSavedWorkoutSnapshot.
    struct ObsidianSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsIncomplete: Bool
        var nextExerciseName: String?
        var nextIsCardio: Bool
        var nextTargetCaption: String?
        var nextLastWorkingCaption: String?
        var canSubtractRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsIncomplete: Bool = false,
            nextExerciseName: String? = nil,
            nextIsCardio: Bool = false,
            nextTargetCaption: String? = nil,
            nextLastWorkingCaption: String? = nil,
            canSubtractRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsIncomplete = focusedIsIncomplete
            self.nextExerciseName = nextExerciseName
            self.nextIsCardio = nextIsCardio
            self.nextTargetCaption = nextTargetCaption
            self.nextLastWorkingCaption = nextLastWorkingCaption
            self.canSubtractRest = canSubtractRest
            self.restEndsAtEpoch = restEndsAtEpoch
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

    static func queueSubtractRestTime() {
        defaults.set(true, forKey: Key.pendingSubtractRestTime)
    }

    static func publishObsidianRestEndsAt(_ date: Date?) {
        if let date, ObsidianAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.obsidianRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.obsidianRestEndsAt)
        }
    }

    static func loadObsidianRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.obsidianRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishObsidianSessionSnapshot(_ snapshot: ObsidianSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.obsidianSessionSnapshot)
    }

    static func loadObsidianSessionSnapshot() -> ObsidianSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.obsidianSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(ObsidianSessionSnapshot.self, from: data)
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

    static func consumePendingSubtractRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingSubtractRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingSubtractRestTime)
        defaults.removeObject(forKey: Key.pendingSubtractRestTime)
        return queued
    }
}
