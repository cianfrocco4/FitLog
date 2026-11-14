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
        static let pendingHalveRestTime = "fitlog.intent.pendingHalveRestTime"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let jadeSessionSnapshot = "fitlog.intent.jadeSessionSnapshot"
        static let jadeRestEndsAt = "fitlog.intent.jadeRestEndsAt"
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

    /// In-progress snapshot for Jade Siri halve-rest / previous-exercise-last-working /
    /// this-exercise-remaining-sets. Distinct from fluoriteSessionSnapshot,
    /// obsidianSessionSnapshot, zirconSessionSnapshot, spinelSessionSnapshot,
    /// alexandriteSessionSnapshot, moonstoneSessionSnapshot,
    /// tanzaniteSessionSnapshot, aquamarineSessionSnapshot,
    /// tourmalineSessionSnapshot, jasperSessionSnapshot,
    /// lapisHistorySnapshot, peridotFinishSnapshot,
    /// onyxNextPlanSnapshot, garnetLibrarySnapshot,
    /// amethystTomorrowSnapshot, emeraldStrengthSnapshot,
    /// sapphireTodaySnapshot, rubyRepeatSnapshot,
    /// citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct JadeSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var focusedExerciseName: String?
        var focusedIsCardio: Bool
        var focusedIsIncomplete: Bool
        var focusedRemainingSetCount: Int
        var previousExerciseName: String?
        var previousIsCardio: Bool
        var previousLastWorkingCaption: String?
        var canHalveRest: Bool
        var restEndsAtEpoch: TimeInterval?
        var hasOpenPlaceholder: Bool
        var isReadyToFinish: Bool

        init(
            inProgressWorkoutName: String? = nil,
            focusedExerciseName: String? = nil,
            focusedIsCardio: Bool = false,
            focusedIsIncomplete: Bool = false,
            focusedRemainingSetCount: Int = 0,
            previousExerciseName: String? = nil,
            previousIsCardio: Bool = false,
            previousLastWorkingCaption: String? = nil,
            canHalveRest: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil,
            hasOpenPlaceholder: Bool = false,
            isReadyToFinish: Bool = false
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.focusedExerciseName = focusedExerciseName
            self.focusedIsCardio = focusedIsCardio
            self.focusedIsIncomplete = focusedIsIncomplete
            self.focusedRemainingSetCount = focusedRemainingSetCount
            self.previousExerciseName = previousExerciseName
            self.previousIsCardio = previousIsCardio
            self.previousLastWorkingCaption = previousLastWorkingCaption
            self.canHalveRest = canHalveRest
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

    static func queueHalveRestTime() {
        defaults.set(true, forKey: Key.pendingHalveRestTime)
    }

    static func publishJadeRestEndsAt(_ date: Date?) {
        if let date, JadeAskFitLog.remainingRestSeconds(restEndsAt: date) != nil {
            defaults.set(date.timeIntervalSince1970, forKey: Key.jadeRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.jadeRestEndsAt)
        }
    }

    static func loadJadeRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.jadeRestEndsAt) as? Double else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch)
    }

    static func publishJadeSessionSnapshot(_ snapshot: JadeSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.jadeSessionSnapshot)
    }

    static func loadJadeSessionSnapshot() -> JadeSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.jadeSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(JadeSessionSnapshot.self, from: data)
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

    static func consumePendingHalveRestTime() -> Bool {
        guard defaults.object(forKey: Key.pendingHalveRestTime) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingHalveRestTime)
        defaults.removeObject(forKey: Key.pendingHalveRestTime)
        return queued
    }
}
