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
        static let pendingDoubleRestTime = "fitlog.intent.pendingDoubleRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let amberSessionSnapshot = "fitlog.intent.amberSessionSnapshot"
        static let amberRestEndsAt = "fitlog.intent.amberRestEndsAt"
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

    /// In-progress snapshot for Amber Siri double-rest / next-exercise-remaining-sets /
    /// this-exercise-last-rest. Distinct from jadeSessionSnapshot,
    /// fluoriteSessionSnapshot, obsidianSessionSnapshot, zirconSessionSnapshot,
    /// spinelSessionSnapshot, alexandriteSessionSnapshot,
    /// moonstoneSessionSnapshot, tanzaniteSessionSnapshot,
    /// aquamarineSessionSnapshot, tourmalineSessionSnapshot,
    /// jasperSessionSnapshot, lapisHistorySnapshot, peridotFinishSnapshot,
    /// onyxNextPlanSnapshot, garnetLibrarySnapshot,
    /// amethystTomorrowSnapshot, emeraldStrengthSnapshot,
    /// sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct AmberSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsCardio: Bool
        var focusedIsIncomplete: Bool
        var focusedLastRestSeconds: Int?
        var nextExerciseName: String?
        var nextIsCardio: Bool
        var nextRemainingSetCount: Int
        var canDoubleRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsCardio: Bool = false,
            focusedIsIncomplete: Bool = false,
            focusedLastRestSeconds: Int? = nil,
            nextExerciseName: String? = nil,
            nextIsCardio: Bool = false,
            nextRemainingSetCount: Int = 0,
            canDoubleRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsCardio = focusedIsCardio
            self.focusedIsIncomplete = focusedIsIncomplete
            self.focusedLastRestSeconds = focusedLastRestSeconds
            self.nextExerciseName = nextExerciseName
            self.nextIsCardio = nextIsCardio
            self.nextRemainingSetCount = nextRemainingSetCount
            self.canDoubleRest = canDoubleRest
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

    static func queueDoubleRestTime() {
        defaults.set(true, forKey: Key.pendingDoubleRestTime)
    }

    static func publishAmberRestEndsAt(_ date: Date?) {
        if let date, AmberAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.amberRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.amberRestEndsAt)
        }
    }

    static func loadAmberRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.amberRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishAmberSessionSnapshot(_ snapshot: AmberSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.amberSessionSnapshot)
    }

    static func loadAmberSessionSnapshot() -> AmberSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.amberSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(AmberSessionSnapshot.self, from: data)
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

    static func consumePendingDoubleRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingDoubleRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingDoubleRestTime)
        defaults.removeObject(forKey: Key.pendingDoubleRestTime)
        return queued
    }
}
