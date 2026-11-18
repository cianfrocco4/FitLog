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
        static let pendingUseNextLastRestTime = "fitlog.intent.pendingUseNextLastRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let larimarSessionSnapshot = "fitlog.intent.larimarSessionSnapshot"
        static let larimarRestEndsAt = "fitlog.intent.larimarRestEndsAt"
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

    /// In-progress snapshot for Larimar Siri use-next-last-rest /
    /// previous-exercise-prescribed-rest / this-workout-last-rest.
    /// Distinct from turquoiseSessionSnapshot, coralSessionSnapshot,
    /// amberSessionSnapshot, jadeSessionSnapshot, fluoriteSessionSnapshot,
    /// obsidianSessionSnapshot, zirconSessionSnapshot, spinelSessionSnapshot,
    /// alexandriteSessionSnapshot, moonstoneSessionSnapshot,
    /// tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot,
    /// lapisHistorySnapshot, peridotFinishSnapshot, onyxNextPlanSnapshot,
    /// garnetLibrarySnapshot, amethystTomorrowSnapshot,
    /// emeraldStrengthSnapshot, sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct LarimarSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsCardio: Bool
        var focusedIsIncomplete: Bool
        var previousExerciseName: String?
        var previousIsCardio: Bool
        var previousPrescribedRestSeconds: Int?
        var nextExerciseName: String?
        var nextIsCardio: Bool
        var nextLastRestSeconds: Int?
        var sessionLastRestSeconds: Int?
        var sessionLastRestExerciseName: String?
        var canUseNextLastRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsCardio: Bool = false,
            focusedIsIncomplete: Bool = false,
            previousExerciseName: String? = nil,
            previousIsCardio: Bool = false,
            previousPrescribedRestSeconds: Int? = nil,
            nextExerciseName: String? = nil,
            nextIsCardio: Bool = false,
            nextLastRestSeconds: Int? = nil,
            sessionLastRestSeconds: Int? = nil,
            sessionLastRestExerciseName: String? = nil,
            canUseNextLastRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsCardio = focusedIsCardio
            self.focusedIsIncomplete = focusedIsIncomplete
            self.previousExerciseName = previousExerciseName
            self.previousIsCardio = previousIsCardio
            self.previousPrescribedRestSeconds = previousPrescribedRestSeconds
            self.nextExerciseName = nextExerciseName
            self.nextIsCardio = nextIsCardio
            self.nextLastRestSeconds = nextLastRestSeconds
            self.sessionLastRestSeconds = sessionLastRestSeconds
            self.sessionLastRestExerciseName = sessionLastRestExerciseName
            self.canUseNextLastRest = canUseNextLastRest
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

    static func queueUseNextLastRestTime() {
        defaults.set(true, forKey: Key.pendingUseNextLastRestTime)
    }

    static func publishLarimarRestEndsAt(_ date: Date?) {
        if let date, LarimarAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.larimarRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.larimarRestEndsAt)
        }
    }

    static func loadLarimarRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.larimarRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishLarimarSessionSnapshot(_ snapshot: LarimarSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.larimarSessionSnapshot)
    }

    static func loadLarimarSessionSnapshot() -> LarimarSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.larimarSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(LarimarSessionSnapshot.self, from: data)
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

    static func consumePendingUseNextLastRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingUseNextLastRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUseNextLastRestTime)
        defaults.removeObject(forKey: Key.pendingUseNextLastRestTime)
        return queued
    }
}
