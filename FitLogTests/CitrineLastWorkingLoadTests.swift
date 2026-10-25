//
//  CitrineLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct CitrineLastWorkingLoadTests {

    @Test func strengthCaptionUsesNewestWorkingSetAndSkipsWarmup() {
        let exerciseId = UUID()
        let older = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
        let newer = session(
            name: "Push A",
            endedAt: Date(),
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        let snapshot = CitrineLastWorkingLoad.querySnapshot(
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(snapshot.lastWorkoutName == "Push A")
        #expect(snapshot.newestCaption == "Last 185 lb × 8 reps")
        #expect(snapshot.captionsByExerciseName["Bench Press"] == "Last 185 lb × 8 reps")
        #expect(
            CitrineLastWorkingLoad.newestCompletedCaption(
                from: [older, newer],
                displayUnit: .pounds
            ) == "Last 185 lb × 8 reps"
        )
    }

    @Test func kilogramsCaptionConvertsStoredPounds() {
        let exerciseId = UUID()
        let logged = session(
            name: "Push A",
            endedAt: Date(),
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
        let kg = WeightStoreConversion.displayValue(storedPounds: 185, unit: .kilograms)
        let expected = "Last \(WeightStoreConversion.formatDisplay(kg)) kg × 8 reps"
        #expect(
            CitrineLastWorkingLoad.newestCompletedCaption(
                from: [logged],
                displayUnit: .kilograms
            ) == expected
        )
    }

    @Test func cardioCaptionUsesNewestDurationAndSkipsIntervalRest() {
        let exerciseId = UUID()
        let older = session(
            name: "Zone 2 · 20 min",
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            exerciseName: "Zone 2",
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 20 * 60, source: .manual)
                )
            ]
        )
        let newer = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            exerciseId: exerciseId,
            exerciseName: "Zone 2",
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .intervalRest,
                    cardioMetrics: CardioMetrics(durationSec: 30, source: .timer)
                ),
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

        let snapshot = CitrineLastWorkingLoad.querySnapshot(
            from: [newer, older],
            displayUnit: .pounds
        )
        #expect(snapshot.lastWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.newestCaption == "Last 45:00")
        #expect(snapshot.lastCardioCaption == "Last 45:00")
        #expect(snapshot.captionsByExerciseName["Zone 2"] == "Last 45:00")
        #expect(
            CitrineLastWorkingLoad.lastCardioDurationCaption(from: [newer, older]) == "Last 45:00"
        )
    }

    @Test func lastWorkoutDialogIncludesLastLoad() {
        let snapshot = FitLogIntentBridge.LastLoadQuerySnapshot(
            lastWorkoutName: "Push A",
            newestCaption: "Last 185 lb × 8 reps"
        )
        #expect(
            CitrineLastWorkingLoad.lastWorkoutDialog(snapshot: snapshot)
                == "Last workout: Push A. Last 185 lb × 8 reps."
        )
        #expect(
            CitrineLastWorkingLoad.lastWorkoutDialog(
                snapshot: .init(lastWorkoutName: "Push A")
            ) == "Last workout: Push A."
        )
        #expect(
            CitrineLastWorkingLoad.lastWorkoutDialog(snapshot: nil)
                == CitrineLastWorkingLoad.noCompletedWorkoutDialog
        )
    }

    @Test func lastLoadDialogPrefersMatchingExerciseName() {
        let snapshot = FitLogIntentBridge.LastLoadQuerySnapshot(
            lastWorkoutName: "Push A",
            newestCaption: "Last 135 lb × 10 reps",
            lastCardioCaption: "Last 45:00",
            captionsByExerciseName: [
                "Bench Press": "Last 185 lb × 8 reps",
                "Zone 2": "Last 45:00"
            ]
        )
        #expect(
            CitrineLastWorkingLoad.lastLoadDialog(
                exerciseName: "bench press",
                snapshot: snapshot
            ) == "bench press: Last 185 lb × 8 reps."
        )
        #expect(
            CitrineLastWorkingLoad.lastLoadDialog(
                exerciseName: nil,
                snapshot: snapshot
            ) == "Last 135 lb × 10 reps (Push A)."
        )
        #expect(
            CitrineLastWorkingLoad.lastLoadDialog(
                exerciseName: "Unknown Lift",
                snapshot: snapshot
            ) == "No last working load for Unknown Lift."
        )
        #expect(
            CitrineLastWorkingLoad.lastLoadDialog(exerciseName: nil, snapshot: nil)
                == CitrineLastWorkingLoad.noLastLoadDialog
        )
    }

    @Test func restTimerDialogIncludesLastLoad() {
        let snapshot = FitLogIntentBridge.LastLoadQuerySnapshot(
            newestCaption: "Last 185 lb × 8 reps"
        )
        #expect(
            CitrineLastWorkingLoad.restTimerDialog(
                durationSeconds: 90,
                snapshot: snapshot
            ) == "Resting 90 seconds. Last 185 lb × 8 reps."
        )
        #expect(
            CitrineLastWorkingLoad.restTimerDialog(
                durationSeconds: 90,
                snapshot: nil
            ) == "Resting 90 seconds."
        )
    }

    @Test func incompleteSessionsAreIgnored() {
        let exerciseId = UUID()
        let open = session(
            name: "In progress",
            endedAt: nil,
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
        let snapshot = CitrineLastWorkingLoad.querySnapshot(
            from: [open],
            displayUnit: .pounds
        )
        #expect(snapshot.lastWorkoutName == nil)
        #expect(snapshot.newestCaption == nil)
        #expect(
            CitrineLastWorkingLoad.lastWorkoutDialog(snapshot: snapshot)
                == CitrineLastWorkingLoad.noCompletedWorkoutDialog
        )
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        exerciseId: UUID,
        exerciseName: String,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let workoutExercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: exerciseId,
                nameAtTimeOfLog: exerciseName
            ))
        )
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: workoutExercise,
            loggedSets: sets
        )
        let workout = Workout(id: UUID(), name: name, exercises: [workoutExercise])
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: (endedAt ?? Date()).addingTimeInterval(-3_600),
            endTime: endedAt,
            exerciseLogs: [log]
        )
    }
}
