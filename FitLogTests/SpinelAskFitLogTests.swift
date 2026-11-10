//
//  SpinelAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct SpinelAskFitLogTests {

    @Test func focusPreviousPrefersRowBeforeActiveIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
            activeExerciseIds: [inclineId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 70,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.focusedCaption == "70 lb × 10 reps")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.canFocusPrevious)
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousExerciseCaption == "185 lb × 8 reps")
        #expect(snapshot.focusedWorkingSetsLogged == 1)
        #expect(snapshot.focusedRecommendedSets == 3)
        #expect(SpinelAskFitLog.canFocusPrevious(snapshot: snapshot))
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Now on Bench Press. Last was 185 lb × 8 reps."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "Previous is Bench Press. Last was 185 lb × 8 reps."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Incline Press: 1 of 3 working sets. Last was 70 lb × 10 reps."
        )
        let target = SpinelAskFitLog.focusPreviousTarget(in: live, displayUnit: .pounds)
        #expect(target?.exerciseName == "Bench Press")
        #expect(target?.exerciseId == benchId)
    }

    @Test func focusedCompleteExerciseStillMovesToPreviousIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [inclineId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 70,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.focusedIsIncomplete == false)
        #expect(snapshot.canFocusPrevious)
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Now on Bench Press. Last was 185 lb × 8 reps."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "Previous is Bench Press. Last was 185 lb × 8 reps."
        )
        #expect(SpinelAskFitLog.focusPreviousTarget(in: live, displayUnit: .pounds)?.exerciseId == benchId)
    }

    @Test func nothingFocusedSelectsLastIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [
                ("Bench Press", benchId, 3, nil, []),
                ("Incline Press", inclineId, 3, nil, [])
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.canFocusPrevious)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Now on Incline Press."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "Previous is Incline Press."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == SpinelAskFitLog.nothingFocusedDialog
        )
        #expect(SpinelAskFitLog.focusPreviousTarget(in: live, displayUnit: .pounds)?.exerciseId == inclineId)
    }

    @Test func alreadyOnOnlyIncompleteDoesNotQueueAnotherFocus() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 180,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
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
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canFocusPrevious == false)
        #expect(snapshot.focusedIsIncomplete)
        #expect(SpinelAskFitLog.canFocusPrevious(snapshot: snapshot) == false)
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Bench Press: 1 of 3 working sets. Last was 185 lb × 8 reps."
        )
        #expect(SpinelAskFitLog.focusPreviousTarget(in: live, displayUnit: .pounds) == nil)
    }

    @Test func wrapsFromFirstIncompleteToLaterIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let flyesId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 300,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, nil, []),
                ("Incline Press", inclineId, 3, nil, []),
                ("Flyes", flyesId, 3, nil, [])
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.previousExerciseName == "Flyes")
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Now on Flyes."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "Previous is Flyes."
        )
        #expect(SpinelAskFitLog.focusPreviousTarget(in: live, displayUnit: .pounds)?.exerciseId == flyesId)
    }

    @Test func warmupDoesNotBecomeLastLoadCaptionOrWorkingSet() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 240,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 5,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ("Incline Press", inclineId, 3, nil, [])
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedCaption == "185 lb × 5 reps")
        #expect(snapshot.focusedWorkingSetsLogged == 1)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Bench Press: 1 of 3 working sets. Last was 185 lb × 5 reps."
        )
    }

    @Test func cardioWithoutDurationStaysIncomplete() {
        let zoneId = UUID()
        let live = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
            duration: 120,
            activeExerciseIds: [zoneId],
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(),
                    []
                )
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canFocusPrevious == false)
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.focusedIsCardio)
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Already on Zone 2."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Zone 2 still needs a duration."
        )
    }

    @Test func cardioDurationMakesSessionReady() {
        let zoneId = UUID()
        let live = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
            duration: 900,
            activeExerciseIds: [zoneId],
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                )
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canFocusPrevious == false)
        #expect(snapshot.focusedCaption == "45 minutes")
        #expect(snapshot.focusedIsCardio)
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "No previous exercise. Zone 2 · 45 min is ready to finish."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "No previous exercise. Zone 2 · 45 min is ready to finish."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Zone 2: 45 minutes logged."
        )
    }

    @Test func prescribedWorkingSetsMakeSessionReady() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 900,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    (0..<3).map { offset in
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(TimeInterval(offset)),
                            setType: .working
                        )
                    }
                )
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canFocusPrevious == false)
        #expect(snapshot.focusedWorkingSetsLogged == 3)
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "No previous exercise. Push A is ready to finish."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Bench Press: 3 of 3 working sets. Last was 185 lb × 8 reps."
        )
    }

    @Test func missingAndFinishedSessionsStayQuiet() {
        let missing = SpinelAskFitLog.querySnapshot(inProgress: nil, displayUnit: .pounds)
        #expect(missing.inProgressWorkoutName == nil)
        #expect(SpinelAskFitLog.canFocusPrevious(snapshot: missing) == false)
        #expect(SpinelAskFitLog.focusPreviousDialog(snapshot: missing) == SpinelAskFitLog.noInProgressDialog)
        #expect(SpinelAskFitLog.previousExerciseDialog(snapshot: missing) == SpinelAskFitLog.noInProgressDialog)
        #expect(SpinelAskFitLog.thisExerciseSetsDialog(snapshot: missing) == SpinelAskFitLog.noInProgressDialog)

        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    3,
                    nil,
                    [
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
            ]
        )
        let finishedSnapshot = SpinelAskFitLog.querySnapshot(
            inProgress: finished,
            displayUnit: .pounds
        )
        #expect(finishedSnapshot.canFocusPrevious == false)
        #expect(finishedSnapshot.isReadyToFinish == false)
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: finishedSnapshot)
                == SpinelAskFitLog.noInProgressDialog
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: finishedSnapshot)
                == SpinelAskFitLog.noInProgressDialog
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: finishedSnapshot)
                == SpinelAskFitLog.noInProgressDialog
        )
    }

    @Test func openSlotPlaceholderCannotBeFocused() {
        let openSlot = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: UUID(),
                    label: "Pick later",
                    targetedMuscles: [.chest],
                    defaultExerciseId: nil
                )
            ),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [openSlot]),
            startTime: Date().addingTimeInterval(-120),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: openSlot,
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.canFocusPrevious == false)
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.isReadyToFinish == false)
        #expect(SpinelAskFitLog.focusPreviousTarget(in: live, displayUnit: .pounds) == nil)
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            SpinelAskFitLog.previousExerciseDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            SpinelAskFitLog.thisExerciseSetsDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
    }

    @Test func kilogramsCaptionUsesDisplayUnit() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            activeExerciseIds: [inclineId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ("Incline Press", inclineId, 3, nil, [])
            ]
        )
        let snapshot = SpinelAskFitLog.querySnapshot(inProgress: live, displayUnit: .kilograms)
        #expect(snapshot.previousExerciseCaption == "83.9 kg × 8 reps")
        #expect(
            SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
                == "Now on Bench Press. Last was 83.9 kg × 8 reps."
        )
    }

    @Test func spinelSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.SpinelSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedCaption: "70 lb × 10 reps",
            focusedIsIncomplete: true,
            focusedIsCardio: false,
            focusedWorkingSetsLogged: 1,
            focusedRecommendedSets: 3,
            previousExerciseName: "Bench Press",
            previousExerciseCaption: "185 lb × 8 reps",
            canFocusPrevious: true,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishSpinelSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadSpinelSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueFocusPreviousExercise()
        #expect(FitLogIntentBridge.consumePendingFocusPreviousExercise())
        #expect(FitLogIntentBridge.consumePendingFocusPreviousExercise() == false)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        startOverride: Date? = nil,
        exercises: [(String, UUID, Int, CardioPrescription?, [LoggedSet])]
    ) -> WorkoutSession {
        let logs: [ExerciseLog] = exercises.map { exerciseName, exerciseId, recommendedSets, cardio, sets in
            let workoutExercise = WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: exerciseId,
                    nameAtTimeOfLog: exerciseName
                )),
                recommendedSets: recommendedSets,
                cardioPrescription: cardio
            )
            return ExerciseLog(
                id: UUID(),
                workoutExercise: workoutExercise,
                loggedSets: sets
            )
        }
        let workout = Workout(id: UUID(), name: name, exercises: logs.map(\.workoutExercise))
        let end = endedAt
        let start: Date
        if let startOverride {
            start = startOverride
        } else if let end {
            start = end.addingTimeInterval(TimeInterval(-duration))
        } else {
            start = Date().addingTimeInterval(TimeInterval(-duration))
        }
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: start,
            endTime: end,
            exerciseLogs: logs,
            activeExerciseIds: activeExerciseIds,
            completedExerciseIds: completedExerciseIds
        )
    }
}
