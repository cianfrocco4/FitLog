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
        static let pendingUsePreviousExerciseLastWorkingRestTime = "fitlog.intent.pendingUsePreviousExerciseLastWorkingRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let berylSessionSnapshot = "fitlog.intent.berylSessionSnapshot"
        static let berylRestEndsAt = "fitlog.intent.berylRestEndsAt"
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

    /// In-progress snapshot for Beryl Siri use-previous-exercise-last-working-rest /
    /// previous-exercise-last-working-rest / previous-exercise-working-sets-logged.
    /// Distinct from kyaniteSessionSnapshot, ioliteSessionSnapshot,
    /// azuriteSessionSnapshot, malachiteSessionSnapshot,
    /// hematiteSessionSnapshot, sunstoneSessionSnapshot,
    /// larimarSessionSnapshot, turquoiseSessionSnapshot,
    /// coralSessionSnapshot, amberSessionSnapshot, jadeSessionSnapshot,
    /// fluoriteSessionSnapshot, obsidianSessionSnapshot,
    /// zirconSessionSnapshot, spinelSessionSnapshot,
    /// alexandriteSessionSnapshot, moonstoneSessionSnapshot,
    /// tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot,
    /// lapisHistorySnapshot, peridotFinishSnapshot, onyxNextPlanSnapshot,
    /// garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct BerylSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsIncomplete: Bool
        var focusedIsPlaceholder: Bool
        var previousExerciseName: String?
        var previousIsIncomplete: Bool
        var previousIsPlaceholder: Bool
        var lastWorkingRestSeconds: Int?
        var lastWorkingRestExerciseName: String?
        var workingSetsLogged: Int
        var canUseLastWorkingRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsIncomplete: Bool = false,
            focusedIsPlaceholder: Bool = false,
            previousExerciseName: String? = nil,
            previousIsIncomplete: Bool = false,
            previousIsPlaceholder: Bool = false,
            lastWorkingRestSeconds: Int? = nil,
            lastWorkingRestExerciseName: String? = nil,
            workingSetsLogged: Int = 0,
            canUseLastWorkingRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsIncomplete = focusedIsIncomplete
            self.focusedIsPlaceholder = focusedIsPlaceholder
            self.previousExerciseName = previousExerciseName
            self.previousIsIncomplete = previousIsIncomplete
            self.previousIsPlaceholder = previousIsPlaceholder
            self.lastWorkingRestSeconds = lastWorkingRestSeconds
            self.lastWorkingRestExerciseName = lastWorkingRestExerciseName
            self.workingSetsLogged = workingSetsLogged
            self.canUseLastWorkingRest = canUseLastWorkingRest
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

    static func queueUsePreviousExerciseLastWorkingRestTime() {
        defaults.set(true, forKey: Key.pendingUsePreviousExerciseLastWorkingRestTime)
    }

    static func publishBerylRestEndsAt(_ date: Date?) {
        if let date, BerylAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.berylRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.berylRestEndsAt)
        }
    }

    static func loadBerylRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.berylRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishBerylSessionSnapshot(_ snapshot: BerylSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.berylSessionSnapshot)
    }

    static func loadBerylSessionSnapshot() -> BerylSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.berylSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(BerylSessionSnapshot.self, from: data)
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

    static func consumePendingUsePreviousExerciseLastWorkingRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingUsePreviousExerciseLastWorkingRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUsePreviousExerciseLastWorkingRestTime)
        defaults.removeObject(forKey: Key.pendingUsePreviousExerciseLastWorkingRestTime)
        return queued
    }
}
