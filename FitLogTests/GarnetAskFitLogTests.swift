//
//  GarnetAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct GarnetAskFitLogTests {

    @Test func nextSavedWorkoutRotatesAndUsesLastWorkingLoadSkippingWarmups() {
        let olderPull = session(
            name: "Pull A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 3_600,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let newerPush = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_700,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [olderPull, newerPush],
            savedWorkoutNames: ["Push A", "Pull A", "Legs A"],
            displayUnit: .pounds
        )
        #expect(snapshot.savedWorkoutNames == ["Push A", "Pull A", "Legs A"])
        #expect(snapshot.lastCompletedWorkoutName == "Push A")
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == "Last 135 lb × 10 reps")
        #expect(snapshot.lastCaptionByWorkoutName["push a"] == "Last 185 lb × 8 reps")
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Pull A")
        #expect(GarnetAskFitLog.isStartableSavedWorkout(snapshot: snapshot))
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A. Last 135 lb × 10 reps."
        )
        #expect(
            GarnetAskFitLog.nextSavedWorkoutDialog(snapshot: snapshot)
                == "Next saved workout is Pull A. Last 135 lb × 10 reps."
        )
        #expect(
            GarnetAskFitLog.savedWorkoutsDialog(snapshot: snapshot)
                == "Saved workouts: Push A, Pull A, Legs A."
        )
    }

    @Test func lastLibraryWorkoutWrapsToFirstDifferentSaved() {
        let legs = session(
            name: "Legs A",
            endedAt: Date(),
            duration: 3_000,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 225,
                    reps: 5,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [legs],
            savedWorkoutNames: ["Push A", "Pull A", "Legs A"],
            displayUnit: .pounds
        )
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Push A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
        #expect(
            GarnetAskFitLog.nextSavedWorkoutDialog(snapshot: snapshot)
                == "Next saved workout is Push A."
        )
    }

    @Test func singleSavedWorkoutStillStartsAfterMatchingLastSession() {
        let logged = session(
            name: "Push A",
            endedAt: Date(),
            duration: 3_600,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [logged],
            savedWorkoutNames: ["Push A"],
            displayUnit: .pounds
        )
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Push A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Push A. Last 185 lb × 8 reps."
        )
        #expect(
            GarnetAskFitLog.savedWorkoutsDialog(snapshot: snapshot)
                == "Saved workouts: Push A."
        )
    }

    @Test func emptyLibraryDoesNotStart() {
        let logged = session(
            name: "Push A",
            endedAt: Date(),
            duration: 3_600,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let empty = GarnetAskFitLog.querySnapshot(
            from: [logged],
            savedWorkoutNames: ["  ", ""],
            displayUnit: .pounds
        )
        #expect(empty.savedWorkoutNames.isEmpty)
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: empty) == nil)
        #expect(GarnetAskFitLog.isStartableSavedWorkout(snapshot: empty) == false)
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: empty)
                == GarnetAskFitLog.noSavedWorkoutDialog
        )
        #expect(
            GarnetAskFitLog.nextSavedWorkoutDialog(snapshot: empty)
                == GarnetAskFitLog.noSavedWorkoutDialog
        )
        #expect(
            GarnetAskFitLog.savedWorkoutsDialog(snapshot: empty)
                == GarnetAskFitLog.noSavedWorkoutDialog
        )
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: nil)
                == GarnetAskFitLog.noSavedWorkoutDialog
        )
        #expect(GarnetAskFitLog.isStartableSavedWorkout(snapshot: nil) == false)
    }

    @Test func lastCompletedOutsideLibraryStartsFirstSaved() {
        let zone2 = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            duration: 45 * 60,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [zone2],
            savedWorkoutNames: ["Push A", "Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCompletedWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.lastCaptionByWorkoutName["zone 2 · 45 min"] == "Last 45:00")
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Push A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
    }

    @Test func noCompletedSessionsStartsFirstSavedWithoutCaption() {
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [],
            savedWorkoutNames: ["Push A", "Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCompletedWorkoutName == nil)
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Push A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
        #expect(
            GarnetAskFitLog.nextSavedWorkoutDialog(snapshot: snapshot)
                == "Next saved workout is Push A."
        )
    }

    @Test func duplicateLibraryNamesSkipToDifferentWorkout() {
        let logged = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_400,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [logged],
            savedWorkoutNames: ["Push A", "push a", "Pull A"],
            displayUnit: .pounds
        )
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Pull A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A."
        )
    }

    @Test func kilogramsCaptionConvertsStoredPoundsForNextSaved() {
        let pull = session(
            name: "Pull A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 3_600,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let push = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_700,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let kg = WeightStoreConversion.displayValue(storedPounds: 135, unit: .kilograms)
        let expected = "Last \(WeightStoreConversion.formatDisplay(kg)) kg × 10 reps"
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [pull, push],
            savedWorkoutNames: ["Push A", "Pull A"],
            displayUnit: .kilograms
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == expected)
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A. \(expected)."
        )
        #expect(
            GarnetAskFitLog.nextSavedWorkoutDialog(snapshot: snapshot)
                == "Next saved workout is Pull A. \(expected)."
        )
    }

    @Test func incompleteSessionsAreIgnoredForLastCompletedAndCaptions() {
        let open = session(
            name: "In progress",
            endedAt: nil,
            duration: 1_800,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 225,
                    reps: 3,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [open],
            savedWorkoutNames: ["Push A", "Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCompletedWorkoutName == nil)
        #expect(snapshot.lastCaptionByWorkoutName.isEmpty)
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Push A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
    }

    @Test func hybridSessionPrefersWorkingLoadCaptionForMatchingName() {
        let hybrid = session(
            name: "Pull A",
            endedAt: Date(),
            duration: 3_900,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 10 * 60, source: .timer)
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [hybrid],
            savedWorkoutNames: ["Push A", "Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == "Last 135 lb × 10 reps")
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Push A")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
    }

    @Test func warmupOnlySessionOmitsLoadCaption() {
        let warmup = session(
            name: "Pull A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 600,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
                )
            ]
        )
        let push = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_400,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [warmup, push],
            savedWorkoutNames: ["Push A", "Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == nil)
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A."
        )
    }

    @Test func cardioNextSavedUsesLastDurationCaption() {
        let zone2 = session(
            name: "Zone 2 · 45 min",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 45 * 60,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )
        let push = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_400,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = GarnetAskFitLog.querySnapshot(
            from: [zone2, push],
            savedWorkoutNames: ["Push A", "Zone 2 · 45 min"],
            displayUnit: .pounds
        )
        #expect(GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) == "Zone 2 · 45 min")
        #expect(
            GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
                == "Starting Zone 2 · 45 min. Last 45:00."
        )
        #expect(
            GarnetAskFitLog.nextSavedWorkoutDialog(snapshot: snapshot)
                == "Next saved workout is Zone 2 · 45 min. Last 45:00."
        )
    }

    @Test func garnetLibrarySnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.GarnetLibrarySnapshot(
            savedWorkoutNames: ["Push A", "Pull A"],
            lastCompletedWorkoutName: "Push A",
            lastCaptionByWorkoutName: [
                "push a": "Last 185 lb × 8 reps",
                "pull a": "Last 135 lb × 10 reps"
            ]
        )
        FitLogIntentBridge.publishGarnetLibrarySnapshot(original)
        let loaded = FitLogIntentBridge.loadGarnetLibrarySnapshot()
        #expect(loaded == original)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let workoutExercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: UUID(),
                nameAtTimeOfLog: "Movement"
            ))
        )
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: workoutExercise,
            loggedSets: sets
        )
        let workout = Workout(id: UUID(), name: name, exercises: [workoutExercise])
        let end = endedAt
        let start: Date
        if let end {
            start = end.addingTimeInterval(TimeInterval(-duration))
        } else {
            start = Date().addingTimeInterval(TimeInterval(-duration))
        }
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: start,
            endTime: end,
            exerciseLogs: [log]
        )
    }
}
