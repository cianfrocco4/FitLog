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
        static let pendingUsePreviousPrescribedRestTime = "fitlog.intent.pendingUsePreviousPrescribedRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let hematiteSessionSnapshot = "fitlog.intent.hematiteSessionSnapshot"
        static let hematiteRestEndsAt = "fitlog.intent.hematiteRestEndsAt"
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

    /// In-progress snapshot for Hematite Siri use-previous-prescribed-rest /
    /// this-exercise-last-rest / this-workout-exercises-completed.
    /// Distinct from sunstoneSessionSnapshot, larimarSessionSnapshot,
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
    struct HematiteSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsIncomplete: Bool
        var focusedLastRestSeconds: Int?
        var previousExerciseName: String?
        var previousIsCardio: Bool
        var previousPrescribedRestSeconds: Int?
        var completedExerciseCount: Int
        var canUsePreviousPrescribedRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsIncomplete: Bool = false,
            focusedLastRestSeconds: Int? = nil,
            previousExerciseName: String? = nil,
            previousIsCardio: Bool = false,
            previousPrescribedRestSeconds: Int? = nil,
            completedExerciseCount: Int = 0,
            canUsePreviousPrescribedRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsIncomplete = focusedIsIncomplete
            self.focusedLastRestSeconds = focusedLastRestSeconds
            self.previousExerciseName = previousExerciseName
            self.previousIsCardio = previousIsCardio
            self.previousPrescribedRestSeconds = previousPrescribedRestSeconds
            self.completedExerciseCount = completedExerciseCount
            self.canUsePreviousPrescribedRest = canUsePreviousPrescribedRest
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

    static func queueUsePreviousPrescribedRestTime() {
        defaults.set(true, forKey: Key.pendingUsePreviousPrescribedRestTime)
    }

    static func publishHematiteRestEndsAt(_ date: Date?) {
        if let date, HematiteAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.hematiteRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.hematiteRestEndsAt)
        }
    }

    static func loadHematiteRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.hematiteRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishHematiteSessionSnapshot(_ snapshot: HematiteSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.hematiteSessionSnapshot)
    }

    static func loadHematiteSessionSnapshot() -> HematiteSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.hematiteSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(HematiteSessionSnapshot.self, from: data)
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

    static func consumePendingUsePreviousPrescribedRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingUsePreviousPrescribedRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUsePreviousPrescribedRestTime)
        defaults.removeObject(forKey: Key.pendingUsePreviousPrescribedRestTime)
        return queued
    }
}
