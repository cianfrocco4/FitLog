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
        static let pendingUseThisWorkoutLastPrescribedRestTime = "fitlog.intent.pendingUseThisWorkoutLastPrescribedRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let azuriteSessionSnapshot = "fitlog.intent.azuriteSessionSnapshot"
        static let azuriteRestEndsAt = "fitlog.intent.azuriteRestEndsAt"
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

    /// In-progress snapshot for Azurite Siri use-this-workout-last-prescribed-rest /
    /// this-workout-last-cardio-duration / this-workout-last-completed-exercise.
    /// Distinct from malachiteSessionSnapshot, hematiteSessionSnapshot,
    /// sunstoneSessionSnapshot, larimarSessionSnapshot,
    /// turquoiseSessionSnapshot, coralSessionSnapshot, amberSessionSnapshot,
    /// jadeSessionSnapshot, fluoriteSessionSnapshot, obsidianSessionSnapshot,
    /// zirconSessionSnapshot, spinelSessionSnapshot,
    /// alexandriteSessionSnapshot, moonstoneSessionSnapshot,
    /// tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot,
    /// lapisHistorySnapshot, peridotFinishSnapshot, onyxNextPlanSnapshot,
    /// garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct AzuriteSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsIncomplete: Bool
        var lastCompletedExerciseName: String?
        var lastCompletedIsCardio: Bool
        var lastCompletedPrescribedRestSeconds: Int?
        var lastCardioExerciseName: String?
        var lastCardioDurationSeconds: Int?
        var canUseLastPrescribedRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsIncomplete: Bool = false,
            lastCompletedExerciseName: String? = nil,
            lastCompletedIsCardio: Bool = false,
            lastCompletedPrescribedRestSeconds: Int? = nil,
            lastCardioExerciseName: String? = nil,
            lastCardioDurationSeconds: Int? = nil,
            canUseLastPrescribedRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsIncomplete = focusedIsIncomplete
            self.lastCompletedExerciseName = lastCompletedExerciseName
            self.lastCompletedIsCardio = lastCompletedIsCardio
            self.lastCompletedPrescribedRestSeconds = lastCompletedPrescribedRestSeconds
            self.lastCardioExerciseName = lastCardioExerciseName
            self.lastCardioDurationSeconds = lastCardioDurationSeconds
            self.canUseLastPrescribedRest = canUseLastPrescribedRest
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

    static func queueUseThisWorkoutLastPrescribedRestTime() {
        defaults.set(true, forKey: Key.pendingUseThisWorkoutLastPrescribedRestTime)
    }

    static func publishAzuriteRestEndsAt(_ date: Date?) {
        if let date, AzuriteAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.azuriteRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.azuriteRestEndsAt)
        }
    }

    static func loadAzuriteRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.azuriteRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishAzuriteSessionSnapshot(_ snapshot: AzuriteSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.azuriteSessionSnapshot)
    }

    static func loadAzuriteSessionSnapshot() -> AzuriteSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.azuriteSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(AzuriteSessionSnapshot.self, from: data)
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

    static func consumePendingUseThisWorkoutLastPrescribedRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingUseThisWorkoutLastPrescribedRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUseThisWorkoutLastPrescribedRestTime)
        defaults.removeObject(forKey: Key.pendingUseThisWorkoutLastPrescribedRestTime)
        return queued
    }
}
