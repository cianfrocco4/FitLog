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
        static let pendingUseLastWeight = "fitlog.intent.pendingUseLastWeight"
        static let pendingSkipRest = "fitlog.intent.pendingSkipRest"
        static let exerciseLibrarySnapshot = "fitlog.intent.exerciseLibrarySnapshot"
        static let aquamarineSessionSnapshot = "fitlog.intent.aquamarineSessionSnapshot"
        static let aquamarineRestEndsAt = "fitlog.intent.aquamarineRestEndsAt"
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

    /// In-progress snapshot for Aquamarine Siri use-last-weight / skip-rest / rest-remaining.
    /// Distinct from tourmalineSessionSnapshot, jasperSessionSnapshot, lapisHistorySnapshot,
    /// peridotFinishSnapshot, onyxNextPlanSnapshot, garnetLibrarySnapshot,
    /// amethystTomorrowSnapshot, emeraldStrengthSnapshot, sapphireTodaySnapshot,
    /// rubyRepeatSnapshot, citrineLastLoadSnapshot, and topaz LastSavedWorkoutSnapshot.
    struct AquamarineSessionSnapshot: Codable, Equatable {
        var inProgressWorkoutName: String?
        var lastWeightExerciseName: String?
        var lastWeightCaption: String?
        var canApplyLastWeight: Bool
        var restEndsAtEpoch: TimeInterval?

        var restEndsAt: Date? {
            restEndsAtEpoch.map { Date(timeIntervalSince1970: $0) }
        }

        init(
            inProgressWorkoutName: String? = nil,
            lastWeightExerciseName: String? = nil,
            lastWeightCaption: String? = nil,
            canApplyLastWeight: Bool = false,
            restEndsAtEpoch: TimeInterval? = nil
        ) {
            self.inProgressWorkoutName = inProgressWorkoutName
            self.lastWeightExerciseName = lastWeightExerciseName
            self.lastWeightCaption = lastWeightCaption
            self.canApplyLastWeight = canApplyLastWeight
            self.restEndsAtEpoch = restEndsAtEpoch
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

    static func queueUseLastWeight() {
        defaults.set(true, forKey: Key.pendingUseLastWeight)
    }

    static func queueSkipRest() {
        defaults.set(true, forKey: Key.pendingSkipRest)
    }

    static func publishRestEndsAt(_ date: Date?) {
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: Key.aquamarineRestEndsAt)
        } else {
            defaults.removeObject(forKey: Key.aquamarineRestEndsAt)
        }
    }

    static func loadRestEndsAt() -> Date? {
        guard let epoch = defaults.object(forKey: Key.aquamarineRestEndsAt) as? NSNumber else {
            return nil
        }
        return Date(timeIntervalSince1970: epoch.doubleValue)
    }

    static func publishAquamarineSessionSnapshot(_ snapshot: AquamarineSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Key.aquamarineSessionSnapshot)
    }

    static func loadAquamarineSessionSnapshot() -> AquamarineSessionSnapshot? {
        guard
            let data = defaults.data(forKey: Key.aquamarineSessionSnapshot),
            let snapshot = try? JSONDecoder().decode(AquamarineSessionSnapshot.self, from: data)
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

    static func consumePendingUseLastWeight() -> Bool {
        guard defaults.object(forKey: Key.pendingUseLastWeight) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingUseLastWeight)
        defaults.removeObject(forKey: Key.pendingUseLastWeight)
        return queued
    }

    static func consumePendingSkipRest() -> Bool {
        guard defaults.object(forKey: Key.pendingSkipRest) != nil else { return false }
        let queued = defaults.bool(forKey: Key.pendingSkipRest)
        defaults.removeObject(forKey: Key.pendingSkipRest)
        return queued
    }
}
