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
        static let pendingUseThisExerciseLastWarmupRestTime = "fitlog.intent.pendingUseThisExerciseLastWarmupRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let hiddeniteSessionSnapshot = "fitlog.intent.hiddeniteSessionSnapshot"
        static let hiddeniteRestEndsAt = "fitlog.intent.hiddeniteRestEndsAt"
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

    /// In-progress snapshot for Hiddenite Siri use-this-exercise-last-warmup-rest /
    /// this-exercise-last-warmup-rest / this-exercise-warmup-sets-logged.
    /// Distinct from kunziteSessionSnapshot, morganiteSessionSnapshot,
    /// berylSessionSnapshot, kyaniteSessionSnapshot,
    /// ioliteSessionSnapshot, azuriteSessionSnapshot,
    /// malachiteSessionSnapshot, hematiteSessionSnapshot,
    /// sunstoneSessionSnapshot, larimarSessionSnapshot,
    /// turquoiseSessionSnapshot, coralSessionSnapshot,
    /// amberSessionSnapshot, jadeSessionSnapshot,
    /// fluoriteSessionSnapshot, obsidianSessionSnapshot,
    /// zirconSessionSnapshot, spinelSessionSnapshot,
    /// alexandriteSessionSnapshot, moonstoneSessionSnapshot,
    /// tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot,
    /// lapisHistorySnapshot, peridotFinishSnapshot, onyxNextPlanSnapshot,
    /// garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct HiddeniteSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsIncomplete: Bool
        var focusedIsPlaceholder: Bool
        var lastWarmupRestSeconds: Int?
        var lastWarmupRestExerciseName: String?
        var warmupSetsLogged: Int
        var canUseLastWarmupRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsIncomplete: Bool = false,
            focusedIsPlaceholder: Bool = false,
            lastWarmupRestSeconds: Int? = nil,
            lastWarmupRestExerciseName: String? = nil,
            warmupSetsLogged: Int = 0,
            canUseLastWarmupRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsIncomplete = focusedIsIncomplete
            self.focusedIsPlaceholder = focusedIsPlaceholder
            self.lastWarmupRestSeconds = lastWarmupRestSeconds
            self.lastWarmupRestExerciseName = lastWarmupRestExerciseName
            self.warmupSetsLogged = warmupSetsLogged
            self.canUseLastWarmupRest = canUseLastWarmupRest
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

    static func queueUseThisExerciseLastWarmupRestTime() {
        defaults.set(true, forKey: Key.pendingUseThisExerciseLastWarmupRestTime)
    }

    static func publishHiddeniteRestEndsAt(_ date: Date?) {
        if let date, HiddeniteAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.hiddeniteRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.hiddeniteRestEndsAt)
        }
    }

    static func loadHiddeniteRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.hiddeniteRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishHiddeniteSessionSnapshot(_ snapshot: HiddeniteSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.hiddeniteSessionSnapshot)
    }

    static func loadHiddeniteSessionSnapshot() -> HiddeniteSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.hiddeniteSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(HiddeniteSessionSnapshot.self, from: data)
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

    static func consumePendingUseThisExerciseLastWarmupRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingUseThisExerciseLastWarmupRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUseThisExerciseLastWarmupRestTime)
        defaults.removeObject(forKey: Key.pendingUseThisExerciseLastWarmupRestTime)
        return queued
    }
}
