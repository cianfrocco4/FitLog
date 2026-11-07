//
//  TanzaniteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct TanzaniteAskFitLogTests {

    @Test func undoPrefersNewestTimestampAndSkipsEmptyPlaceholders() {
        let benchId = UUID()
        let inclineId = UUID()
        let now = Date()
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
                            weight: 0,
                            reps: 0,
                            restTime: 90,
                            timestamp: now.addingTimeInterval(30),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: now.addingTimeInterval(-30),
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
                            timestamp: now,
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.undoExerciseName == "Incline Press")
        #expect(snapshot.undoCaption == "70 lb × 10 reps")
        #expect(snapshot.canUndoLastSet)
        #expect(TanzaniteAskFitLog.canUndoLastSet(snapshot: snapshot))
        #expect(
            TanzaniteAskFitLog.undoLastSetDialog(snapshot: snapshot)
                == "Undid Incline Press. 70 lb × 10 reps."
        )
        let undoable = TanzaniteAskFitLog.undoableLastSet(in: live, displayUnit: .pounds)
        #expect(undoable?.exerciseIndex == 1)
        #expect(undoable?.setIndex == 0)
        #expect(undoable?.exerciseName == "Incline Press")
        #expect(snapshot.loggedSetCount == 2)
        #expect(snapshot.workingSetCount == 2)
        #expect(
            TanzaniteAskFitLog.setsLoggedDialog(snapshot: snapshot)
                == "2 sets logged in Push A."
        )
    }

    @Test func equalTimestampsPreferActiveExercise() {
        let benchId = UUID()
        let inclineId = UUID()
        let stamped = Date()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 180,
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
                            timestamp: stamped,
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
                            timestamp: stamped,
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let undoable = TanzaniteAskFitLog.undoableLastSet(in: live, displayUnit: .pounds)
        #expect(undoable?.exerciseName == "Incline Press")
        #expect(undoable?.exerciseIndex == 1)
    }

    @Test func warmupCountsTowardUndoAndSplitsWorkingCount() {
        let benchId = UUID()
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
                )
            ]
        )
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.loggedSetCount == 2)
        #expect(snapshot.workingSetCount == 1)
        #expect(
            TanzaniteAskFitLog.setsLoggedDialog(snapshot: snapshot)
                == "2 sets logged in Push A. 1 working set."
        )
        #expect(snapshot.undoCaption == "185 lb × 5 reps")
        let afterOlder = session(
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
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let warmupSnapshot = TanzaniteAskFitLog.querySnapshot(
            inProgress: afterOlder,
            displayUnit: .pounds
        )
        #expect(warmupSnapshot.canUndoLastSet)
        #expect(warmupSnapshot.undoCaption == "95 lb × 8 reps")
        #expect(
            TanzaniteAskFitLog.setsLoggedDialog(snapshot: warmupSnapshot)
                == "1 set logged in Push A. 0 working sets."
        )
    }

    @Test func cardioDurationCanBeUndoneAndDoesNotCountAsWorking() {
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
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canUndoLastSet)
        #expect(snapshot.undoExerciseName == "Zone 2")
        #expect(snapshot.undoCaption == "45 minutes")
        #expect(
            TanzaniteAskFitLog.undoLastSetDialog(snapshot: snapshot)
                == "Undid Zone 2. 45 minutes."
        )
        #expect(snapshot.loggedSetCount == 1)
        #expect(snapshot.workingSetCount == 0)
        #expect(
            TanzaniteAskFitLog.setsLoggedDialog(snapshot: snapshot)
                == "1 set logged in Zone 2 · 45 min. 0 working sets."
        )
    }

    @Test func emptyInProgressStaysQuietAndDoesNotQueueUndo() {
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.canUndoLastSet == false)
        #expect(TanzaniteAskFitLog.canUndoLastSet(snapshot: snapshot) == false)
        #expect(TanzaniteAskFitLog.undoLastSetDialog(snapshot: snapshot) == TanzaniteAskFitLog.noSetToUndoDialog)
        #expect(TanzaniteAskFitLog.setsLoggedDialog(snapshot: snapshot) == TanzaniteAskFitLog.noSetsLoggedDialog)
        #expect(TanzaniteAskFitLog.undoableLastSet(in: live, displayUnit: .pounds) == nil)
    }

    @Test func missingAndFinishedSessionsStayQuiet() {
        let missing = TanzaniteAskFitLog.querySnapshot(inProgress: nil, displayUnit: .pounds)
        #expect(missing.inProgressWorkoutName == nil)
        #expect(TanzaniteAskFitLog.canUndoLastSet(snapshot: missing) == false)
        #expect(TanzaniteAskFitLog.undoLastSetDialog(snapshot: missing) == TanzaniteAskFitLog.noInProgressDialog)
        #expect(TanzaniteAskFitLog.setsLoggedDialog(snapshot: missing) == TanzaniteAskFitLog.noInProgressDialog)
        #expect(TanzaniteAskFitLog.elapsedWorkoutDialog(snapshot: missing) == TanzaniteAskFitLog.noInProgressDialog)

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
        let finishedSnapshot = TanzaniteAskFitLog.querySnapshot(
            inProgress: finished,
            displayUnit: .pounds
        )
        #expect(finishedSnapshot.canUndoLastSet == false)
        #expect(
            TanzaniteAskFitLog.undoLastSetDialog(snapshot: finishedSnapshot)
                == TanzaniteAskFitLog.noInProgressDialog
        )
        #expect(
            TanzaniteAskFitLog.setsLoggedDialog(snapshot: finishedSnapshot)
                == TanzaniteAskFitLog.noInProgressDialog
        )
    }

    @Test func openSlotPlaceholderCannotBeUndone() {
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
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.canUndoLastSet == false)
        #expect(snapshot.loggedSetCount == 0)
        #expect(TanzaniteAskFitLog.undoableLastSet(in: live, displayUnit: .pounds) == nil)
    }

    @Test func elapsedUsesWallClockFromStartTime() {
        let now = Date()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 125,
            startOverride: now.addingTimeInterval(-125),
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(TanzaniteAskFitLog.elapsedSeconds(snapshot: snapshot, now: now) == 125)
        #expect(
            TanzaniteAskFitLog.elapsedWorkoutDialog(snapshot: snapshot, now: now)
                == "Workout elapsed: 2 minutes, 5 seconds."
        )
    }

    @Test func kilogramsCaptionUsesDisplayUnit() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
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
        let snapshot = TanzaniteAskFitLog.querySnapshot(inProgress: live, displayUnit: .kilograms)
        #expect(snapshot.undoCaption == "83.9 kg × 8 reps")
        #expect(
            TanzaniteAskFitLog.undoLastSetDialog(snapshot: snapshot)
                == "Undid Bench Press. 83.9 kg × 8 reps."
        )
    }

    @Test func tanzaniteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.TanzaniteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            undoExerciseName: "Bench Press",
            undoCaption: "185 lb × 8 reps",
            canUndoLastSet: true,
            loggedSetCount: 3,
            workingSetCount: 2,
            startTimeEpoch: 1_783_000_000
        )
        FitLogIntentBridge.publishTanzaniteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadTanzaniteSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueUndoLastSet()
        #expect(FitLogIntentBridge.consumePendingUndoLastSet())
        #expect(FitLogIntentBridge.consumePendingUndoLastSet() == false)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
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
            activeExerciseIds: activeExerciseIds
        )
    }
}
