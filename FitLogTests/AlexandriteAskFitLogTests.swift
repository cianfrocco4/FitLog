//
//  AlexandriteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct AlexandriteAskFitLogTests {

    @Test func focusNextPrefersRowAfterActiveIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedCaption == "185 lb × 8 reps")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.canFocusNext)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextExerciseCaption == "70 lb × 10 reps")
        #expect(snapshot.remainingExerciseNames == ["Bench Press", "Incline Press"])
        #expect(snapshot.remainingCount == 2)
        #expect(AlexandriteAskFitLog.canFocusNext(snapshot: snapshot))
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Now on Incline Press. Last was 70 lb × 10 reps."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Bench Press and Incline Press still left on Push A."
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. Focused on Bench Press. Last was 185 lb × 8 reps."
        )
        let target = AlexandriteAskFitLog.focusNextTarget(in: live, displayUnit: .pounds)
        #expect(target?.exerciseName == "Incline Press")
        #expect(target?.exerciseId == inclineId)
    }

    @Test func focusedCompleteExerciseStillAdvancesToNextIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
            activeExerciseIds: [benchId],
            completedExerciseIds: [benchId],
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
                    []
                )
            ]
        )
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete == false)
        #expect(snapshot.canFocusNext)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.remainingExerciseNames == ["Incline Press"])
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Now on Incline Press."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Incline Press still left on Push A."
        )
        #expect(AlexandriteAskFitLog.focusNextTarget(in: live, displayUnit: .pounds)?.exerciseId == inclineId)
    }

    @Test func nothingFocusedSelectsFirstIncomplete() {
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.canFocusNext)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Now on Bench Press."
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress."
        )
        #expect(AlexandriteAskFitLog.focusNextTarget(in: live, displayUnit: .pounds)?.exerciseId == benchId)
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canFocusNext == false)
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.remainingCount == 1)
        #expect(AlexandriteAskFitLog.canFocusNext(snapshot: snapshot) == false)
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Bench Press still left on Push A. Last was 185 lb × 8 reps."
        )
        #expect(AlexandriteAskFitLog.focusNextTarget(in: live, displayUnit: .pounds) == nil)
    }

    @Test func wrapsFromLastIncompleteToEarlierIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let flyesId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 300,
            activeExerciseIds: [flyesId],
            exercises: [
                ("Bench Press", benchId, 3, nil, []),
                ("Incline Press", inclineId, 3, nil, []),
                ("Flyes", flyesId, 3, nil, [])
            ]
        )
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedExerciseName == "Flyes")
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.remainingCount == 3)
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Now on Bench Press."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Bench Press, Incline Press, and Flyes still left on Push A."
        )
        #expect(AlexandriteAskFitLog.focusNextTarget(in: live, displayUnit: .pounds)?.exerciseId == benchId)
    }

    @Test func remainingListTruncatesAfterTwoNames() {
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [
                ("Bench Press", UUID(), 3, nil, []),
                ("Incline Press", UUID(), 3, nil, []),
                ("Flyes", UUID(), 3, nil, []),
                ("Tricep Pushdown", UUID(), 3, nil, [])
            ]
        )
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.remainingCount == 4)
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Bench Press, Incline Press, and 2 more still left on Push A."
        )
    }

    @Test func warmupDoesNotBecomeLastLoadCaption() {
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.focusedCaption == "185 lb × 5 reps")
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. Focused on Bench Press. Last was 185 lb × 5 reps."
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canFocusNext == false)
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.remainingCount == 1)
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Already on Zone 2."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Zone 2 still left on Zone 2 · 45 min."
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Zone 2 · 45 min is in progress. Focused on Zone 2."
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canFocusNext == false)
        #expect(snapshot.focusedCaption == "45 minutes")
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "No next exercise. Zone 2 · 45 min is ready to finish."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Zone 2 · 45 min is ready to finish."
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Zone 2 · 45 min is in progress. Focused on Zone 2. Last was 45 minutes. Ready to finish."
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canFocusNext == false)
        #expect(snapshot.remainingCount == 0)
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "No next exercise. Push A is ready to finish."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Push A is ready to finish."
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. Focused on Bench Press. Last was 185 lb × 8 reps. Ready to finish."
        )
    }

    @Test func missingAndFinishedSessionsStayQuiet() {
        let missing = AlexandriteAskFitLog.querySnapshot(inProgress: nil, displayUnit: .pounds)
        #expect(missing.inProgressWorkoutName == nil)
        #expect(AlexandriteAskFitLog.canFocusNext(snapshot: missing) == false)
        #expect(AlexandriteAskFitLog.focusNextDialog(snapshot: missing) == AlexandriteAskFitLog.noInProgressDialog)
        #expect(AlexandriteAskFitLog.remainingExercisesDialog(snapshot: missing) == AlexandriteAskFitLog.noInProgressDialog)
        #expect(AlexandriteAskFitLog.currentWorkoutDialog(snapshot: missing) == AlexandriteAskFitLog.noInProgressDialog)

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
        let finishedSnapshot = AlexandriteAskFitLog.querySnapshot(
            inProgress: finished,
            displayUnit: .pounds
        )
        #expect(finishedSnapshot.canFocusNext == false)
        #expect(finishedSnapshot.isReadyToFinish == false)
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: finishedSnapshot)
                == AlexandriteAskFitLog.noInProgressDialog
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: finishedSnapshot)
                == AlexandriteAskFitLog.noInProgressDialog
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: finishedSnapshot)
                == AlexandriteAskFitLog.noInProgressDialog
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
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.canFocusNext == false)
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.isReadyToFinish == false)
        #expect(AlexandriteAskFitLog.focusNextTarget(in: live, displayUnit: .pounds) == nil)
        #expect(
            AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            AlexandriteAskFitLog.remainingExercisesDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. It still has an open slot."
        )
    }

    @Test func kilogramsCaptionUsesDisplayUnit() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
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
                ),
                ("Incline Press", inclineId, 3, nil, [])
            ]
        )
        let snapshot = AlexandriteAskFitLog.querySnapshot(inProgress: live, displayUnit: .kilograms)
        #expect(snapshot.focusedCaption == "83.9 kg × 8 reps")
        #expect(
            AlexandriteAskFitLog.currentWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. Focused on Bench Press. Last was 83.9 kg × 8 reps."
        )
    }

    @Test func alexandriteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.AlexandriteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedCaption: "185 lb × 8 reps",
            focusedIsIncomplete: true,
            nextExerciseName: "Incline Press",
            nextExerciseCaption: "70 lb × 10 reps",
            canFocusNext: true,
            remainingExerciseNames: ["Bench Press", "Incline Press"],
            remainingCount: 2,
            firstRemainingCaption: "185 lb × 8 reps",
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishAlexandriteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadAlexandriteSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueFocusNextExercise()
        #expect(FitLogIntentBridge.consumePendingFocusNextExercise())
        #expect(FitLogIntentBridge.consumePendingFocusNextExercise() == false)
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
