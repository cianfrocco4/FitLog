//
//  TopazLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct TopazLastWorkingLoadTests {

    @Test func resolvedStartWorkoutName_requestedNameWins() {
        let snapshot = FitLogIntentBridge.LastSavedWorkoutSnapshot(
            name: "Push A",
            lastLoadCaption: "Last 185 lb × 8 reps"
        )
        #expect(
            TopazLastWorkingLoad.resolvedStartWorkoutName(
                requested: "  Legs A  ",
                snapshot: snapshot
            ) == "Legs A"
        )
    }

    @Test func resolvedStartWorkoutName_fallsBackToLastSaved() {
        let snapshot = FitLogIntentBridge.LastSavedWorkoutSnapshot(name: "Push A")
        #expect(
            TopazLastWorkingLoad.resolvedStartWorkoutName(
                requested: "   ",
                snapshot: snapshot
            ) == "Push A"
        )
        #expect(
            TopazLastWorkingLoad.resolvedStartWorkoutName(
                requested: nil,
                snapshot: snapshot
            ) == "Push A"
        )
    }

    @Test func resolvedStartWorkoutName_nilWhenEmptyLibrary() {
        #expect(
            TopazLastWorkingLoad.resolvedStartWorkoutName(
                requested: nil,
                snapshot: nil
            ) == nil
        )
        #expect(
            TopazLastWorkingLoad.resolvedStartWorkoutName(
                requested: "",
                snapshot: .init(name: "   ")
            ) == nil
        )
    }

    @Test func startLastLoadCaption_onlyWhenStartingLastSaved() {
        let snapshot = FitLogIntentBridge.LastSavedWorkoutSnapshot(
            name: "Push A",
            lastLoadCaption: "Last 185 lb × 8 reps"
        )
        #expect(
            TopazLastWorkingLoad.startLastLoadCaption(
                requested: nil,
                snapshot: snapshot
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            TopazLastWorkingLoad.startLastLoadCaption(
                requested: "Push A",
                snapshot: snapshot
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            TopazLastWorkingLoad.startLastLoadCaption(
                requested: "Legs A",
                snapshot: snapshot
            ) == nil
        )
    }

    @Test func startDialog_includesLastLoadWhenPresent() {
        #expect(
            TopazLastWorkingLoad.startDialog(
                workoutName: "Push A",
                lastLoadCaption: "Last 185 lb × 8 reps"
            ) == "Starting Push A. Last 185 lb × 8 reps."
        )
        #expect(
            TopazLastWorkingLoad.startDialog(
                workoutName: "Push A",
                lastLoadCaption: nil
            ) == "Starting Push A."
        )
    }

    @Test func queuedLogSetMessage_appendsLastLoad() {
        #expect(
            TopazLastWorkingLoad.queuedLogSetMessage(
                reps: 8,
                weightPounds: 185,
                lastLoadCaption: nil
            ) == "Queued 8 reps at 185 lbs — open \(AppBrand.name) to apply"
        )
        #expect(
            TopazLastWorkingLoad.queuedLogSetMessage(
                reps: 8,
                weightPounds: 185,
                lastLoadCaption: "Last 185 lb × 8 reps"
            ) == "Queued 8 reps at 185 lbs — last 185 lb × 8 reps. Open \(AppBrand.name) to apply"
        )
    }

    @Test func lastLoadCaption_prefersMatchingExerciseName() {
        let snapshot = FitLogIntentBridge.LastSavedWorkoutSnapshot(
            name: "Push A",
            lastLoadCaption: "Last 135 lb × 10 reps",
            lastLoadByExerciseName: [
                "Bench Press": "Last 185 lb × 8 reps",
                "Zone 2": "Last 45:00"
            ]
        )
        #expect(
            TopazLastWorkingLoad.lastLoadCaption(
                forExerciseName: "bench press",
                snapshot: snapshot
            ) == "Last 185 lb × 8 reps"
        )
        #expect(
            TopazLastWorkingLoad.lastLoadCaption(
                forExerciseName: "Unknown",
                snapshot: snapshot
            ) == "Last 135 lb × 10 reps"
        )
    }

    @Test func newestCompletedCaption_skipsWarmups() {
        let benchId = UUID()
        let warmupOnly = makeSession(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-7200),
            exerciseId: benchId,
            exerciseName: "Bench Press",
            sets: [
                LoggedSet(id: UUID(), weight: 135, reps: 10, restTime: 60, timestamp: Date(), setType: .warmup)
            ]
        )
        let working = makeSession(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-3600),
            exerciseId: benchId,
            exerciseName: "Bench Press",
            sets: [
                LoggedSet(id: UUID(), weight: 45, reps: 8, restTime: 60, timestamp: Date(), setType: .warmup),
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: Date(), setType: .working)
            ]
        )

        let caption = TopazLastWorkingLoad.newestCompletedCaption(
            from: [warmupOnly, working],
            displayUnit: .pounds
        )
        #expect(caption == "Last 185 lb × 8 reps")
    }

    @Test func newestCompletedCaption_usesLastCardioDuration() {
        let session = makeSession(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            exerciseId: UUID(),
            exerciseName: "Zone 2",
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .manual)
                )
            ]
        )
        let caption = TopazLastWorkingLoad.newestCompletedCaption(
            from: [session],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
    }

    @Test func lastSavedWorkoutSnapshot_prefersMostRecentCompletedLibraryWorkout() {
        let pushId = UUID()
        let legsId = UUID()
        let benchId = UUID()
        let squatId = UUID()
        let library = [
            Workout(id: pushId, name: "Push A", exercises: [
                WorkoutExercise(
                    id: UUID(),
                    resolution: .concrete(ExerciseSnapshot(exerciseId: benchId, nameAtTimeOfLog: "Bench Press"))
                )
            ]),
            Workout(id: legsId, name: "Legs A", exercises: [
                WorkoutExercise(
                    id: UUID(),
                    resolution: .concrete(ExerciseSnapshot(exerciseId: squatId, nameAtTimeOfLog: "Squat"))
                )
            ])
        ]
        let olderPush = makeSession(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: benchId,
            exerciseName: "Bench Press",
            sets: [
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: Date(), setType: .working)
            ],
            libraryWorkoutId: pushId
        )
        let newerLegs = makeSession(
            name: "Legs A",
            endedAt: Date(),
            exerciseId: squatId,
            exerciseName: "Squat",
            sets: [
                LoggedSet(id: UUID(), weight: 225, reps: 5, restTime: 120, timestamp: Date(), setType: .working)
            ],
            libraryWorkoutId: legsId
        )

        let snapshot = TopazLastWorkingLoad.lastSavedWorkoutSnapshot(
            library: library,
            sessions: [olderPush, newerLegs],
            displayUnit: .pounds
        )
        #expect(snapshot?.name == "Legs A")
        #expect(snapshot?.lastLoadCaption == "Last 225 lb × 5 reps")
        #expect(snapshot?.lastLoadByExerciseName["Squat"] == "Last 225 lb × 5 reps")
        #expect(snapshot?.lastLoadByExerciseName["Bench Press"] == "Last 185 lb × 8 reps")
    }

    @Test func lastSavedWorkoutSnapshot_fallsBackToFirstLibraryWorkout() {
        let library = [
            Workout(id: UUID(), name: "Push A", exercises: [])
        ]
        let snapshot = TopazLastWorkingLoad.lastSavedWorkoutSnapshot(
            library: library,
            sessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot?.name == "Push A")
        #expect(snapshot?.lastLoadCaption == nil)
    }

    @Test func lastSavedWorkoutSnapshot_matchesSessionNameWhenOriginMissing() {
        let workoutId = UUID()
        let benchId = UUID()
        let library = [
            Workout(id: workoutId, name: "Push A", exercises: [
                WorkoutExercise(
                    id: UUID(),
                    resolution: .concrete(ExerciseSnapshot(exerciseId: benchId, nameAtTimeOfLog: "Bench Press"))
                )
            ])
        ]
        let session = makeSession(
            name: "push a",
            endedAt: Date(),
            exerciseId: benchId,
            exerciseName: "Bench Press",
            sets: [
                LoggedSet(id: UUID(), weight: 135, reps: 10, restTime: 90, timestamp: Date(), setType: .working)
            ]
        )
        let snapshot = TopazLastWorkingLoad.lastSavedWorkoutSnapshot(
            library: library,
            sessions: [session],
            displayUnit: .pounds
        )
        #expect(snapshot?.name == "Push A")
        #expect(snapshot?.lastLoadCaption == "Last 135 lb × 10 reps")
    }

    @Test func intentBridge_lastSavedWorkout_roundTripAndClear() {
        let suiteName = "fitlog.topaz.intentbridge.tests"
        let suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        defer { suite.removePersistentDomain(forName: suiteName) }

        let keySnapshot = FitLogIntentBridge.LastSavedWorkoutSnapshot(
            name: "Push A",
            lastLoadCaption: "Last 185 lb × 8 reps",
            lastLoadByExerciseName: ["Bench Press": "Last 185 lb × 8 reps"]
        )
        FitLogIntentBridge.publishLastSavedWorkout(keySnapshot, defaults: suite)
        let loaded = FitLogIntentBridge.loadLastSavedWorkout(defaults: suite)
        #expect(loaded == keySnapshot)
        FitLogIntentBridge.publishLastSavedWorkout(nil, defaults: suite)
        #expect(FitLogIntentBridge.loadLastSavedWorkout(defaults: suite) == nil)
    }

    @Test func storedDisplayUnit_readsUserDefaults() {
        let suite = UserDefaults(suiteName: "fitlog.topaz.lastload.tests")!
        suite.removePersistentDomain(forName: "fitlog.topaz.lastload.tests")
        #expect(TopazLastWorkingLoad.storedDisplayUnit(defaults: suite) == .pounds)
        suite.set(WeightDisplayUnit.kilograms.rawValue, forKey: "fitlog.weightDisplayUnit")
        #expect(TopazLastWorkingLoad.storedDisplayUnit(defaults: suite) == .kilograms)
        suite.removePersistentDomain(forName: "fitlog.topaz.lastload.tests")
    }

    private func makeSession(
        name: String,
        endedAt: Date,
        exerciseId: UUID,
        exerciseName: String,
        sets: [LoggedSet],
        libraryWorkoutId: UUID? = nil
    ) -> WorkoutSession {
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: exerciseName))
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryWorkoutId ?? UUID(), name: name, exercises: [row]),
            startTime: endedAt.addingTimeInterval(-3600),
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)],
            sessionPlanOrigin: libraryWorkoutId.map { .workout($0) }
        )
    }
}
