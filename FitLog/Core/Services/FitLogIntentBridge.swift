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
        static let pendingUseThisWorkoutLastRestTime = "fitlog.intent.pendingUseThisWorkoutLastRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let sunstoneSessionSnapshot = "fitlog.intent.sunstoneSessionSnapshot"
        static let sunstoneRestEndsAt = "fitlog.intent.sunstoneRestEndsAt"
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

    /// In-progress snapshot for Sunstone Siri use-this-workout-last-rest /
    /// this-workout-remaining-sets / this-workout-last-working.
    /// Distinct from larimarSessionSnapshot, turquoiseSessionSnapshot,
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
    struct SunstoneSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsIncomplete: Bool
        var remainingSetCount: Int
        var sessionLastRestSeconds: Int?
        var sessionLastRestExerciseName: String?
        var sessionLastWorkingCaption: String?
        var sessionLastWorkingExerciseName: String?
        var canUseThisWorkoutLastRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsIncomplete: Bool = false,
            remainingSetCount: Int = 0,
            sessionLastRestSeconds: Int? = nil,
            sessionLastRestExerciseName: String? = nil,
            sessionLastWorkingCaption: String? = nil,
            sessionLastWorkingExerciseName: String? = nil,
            canUseThisWorkoutLastRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsIncomplete = focusedIsIncomplete
            self.remainingSetCount = remainingSetCount
            self.sessionLastRestSeconds = sessionLastRestSeconds
            self.sessionLastRestExerciseName = sessionLastRestExerciseName
            self.sessionLastWorkingCaption = sessionLastWorkingCaption
            self.sessionLastWorkingExerciseName = sessionLastWorkingExerciseName
            self.canUseThisWorkoutLastRest = canUseThisWorkoutLastRest
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

    static func queueUseThisWorkoutLastRestTime() {
        defaults.set(true, forKey: Key.pendingUseThisWorkoutLastRestTime)
    }

    static func publishSunstoneRestEndsAt(_ date: Date?) {
        if let date, SunstoneAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.sunstoneRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.sunstoneRestEndsAt)
        }
    }

    static func loadSunstoneRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.sunstoneRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishSunstoneSessionSnapshot(_ snapshot: SunstoneSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.sunstoneSessionSnapshot)
    }

    static func loadSunstoneSessionSnapshot() -> SunstoneSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.sunstoneSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(SunstoneSessionSnapshot.self, from: data)
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

    static func consumePendingUseThisWorkoutLastRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingUseThisWorkoutLastRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUseThisWorkoutLastRestTime)
        defaults.removeObject(forKey: Key.pendingUseThisWorkoutLastRestTime)
        return queued
    }
}
