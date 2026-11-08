//
//  MoonstoneAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct MoonstoneAskFitLogTests {

    @Test func skipPrefersActiveIncompleteAndNamesNextUp() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.canSkipRemaining)
        #expect(snapshot.skipExerciseName == "Bench Press")
        #expect(snapshot.skipCaption == "185 lb × 8 reps")
        #expect(snapshot.nextAfterSkipName == "Incline Press")
        #expect(snapshot.nextAfterSkipCaption == "70 lb × 10 reps")
        #expect(snapshot.nextSetExerciseName == "Bench Press")
        #expect(snapshot.nextSetNumber == 2)
        #expect(snapshot.nextSetOf == 3)
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.remainingIncompleteCount == 2)
        #expect(MoonstoneAskFitLog.canSkipRemaining(snapshot: snapshot))
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: snapshot)
                == "Skipped remaining on Bench Press. Last was 185 lb × 8 reps. Next up: Incline Press, last 70 lb × 10 reps."
        )
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "Bench Press, set 2 of 3. Last was 185 lb × 8 reps."
        )
        let target = MoonstoneAskFitLog.skipRemainingTarget(in: live, displayUnit: .pounds)
        #expect(target?.exerciseName == "Bench Press")
        #expect(target?.nextExerciseName == "Incline Press")
        #expect(target?.exerciseId == benchId)
        #expect(target?.nextExerciseId == inclineId)
    }

    @Test func focusedCompleteExerciseDoesNotSkipAnotherRow() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canSkipRemaining == false)
        #expect(MoonstoneAskFitLog.canSkipRemaining(snapshot: snapshot) == false)
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: snapshot)
                == MoonstoneAskFitLog.nothingToSkipDialog
        )
        #expect(snapshot.nextSetExerciseName == "Incline Press")
        #expect(snapshot.nextSetNumber == 1)
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "Incline Press, set 1 of 3."
        )
        #expect(MoonstoneAskFitLog.skipRemainingTarget(in: live, displayUnit: .pounds) == nil)
    }

    @Test func warmupDoesNotAdvanceNextSetNumber() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.nextSetNumber == 2)
        #expect(snapshot.nextSetOf == 3)
        #expect(snapshot.nextSetLastCaption == "185 lb × 5 reps")
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.canSkipRemaining)
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "Bench Press, set 2 of 3. Last was 185 lb × 5 reps."
        )
    }

    @Test func lastIncompleteSkipSpeaksReadyToFinish() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.remainingIncompleteCount == 1)
        #expect(snapshot.nextAfterSkipName == nil)
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: snapshot)
                == "Skipped remaining on Bench Press. Last was 185 lb × 8 reps. Ready to finish."
        )
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "1 exercise still left on Push A."
        )
    }

    @Test func prescribedWorkingSetsMakeSessionReadyWithoutSkip() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canSkipRemaining == false)
        #expect(snapshot.remainingIncompleteCount == 0)
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "Push A is ready to finish."
        )
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "No next set. Push A is ready to finish."
        )
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: snapshot)
                == MoonstoneAskFitLog.nothingToSkipDialog
        )
    }

    @Test func markedDoneCountsAsReadyEvenWithoutWorkingSets() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            activeExerciseIds: [],
            completedExerciseIds: [benchId],
            exercises: [("Bench Press", benchId, 3, nil, [])]
        )
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canSkipRemaining == false)
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "Push A is ready to finish."
        )
    }

    @Test func emptyAndWarmupOnlyStayIncomplete() {
        let benchId = UUID()
        let empty = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [("Bench Press", benchId, 3, nil, [])]
        )
        let emptySnapshot = MoonstoneAskFitLog.querySnapshot(inProgress: empty, displayUnit: .pounds)
        #expect(emptySnapshot.canSkipRemaining)
        #expect(emptySnapshot.isReadyToFinish == false)
        #expect(emptySnapshot.nextSetNumber == 1)
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: emptySnapshot)
                == "Bench Press, set 1 of 3."
        )
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: emptySnapshot)
                == "Skipped remaining on Bench Press. Ready to finish."
        )

        let warmupOnly = session(
            name: "Push A",
            endedAt: nil,
            duration: 90,
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
        let warmupSnapshot = MoonstoneAskFitLog.querySnapshot(
            inProgress: warmupOnly,
            displayUnit: .pounds
        )
        #expect(warmupSnapshot.canSkipRemaining)
        #expect(warmupSnapshot.isReadyToFinish == false)
        #expect(warmupSnapshot.nextSetNumber == 1)
        #expect(warmupSnapshot.nextSetLastCaption == nil)
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: warmupSnapshot)
                == "Bench Press, set 1 of 3."
        )
    }

    @Test func cardioWithoutDurationNeedsDurationAndCanBeSkipped() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.canSkipRemaining)
        #expect(snapshot.isCardioNextSet)
        #expect(snapshot.isReadyToFinish == false)
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "Zone 2 still needs a duration."
        )
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: snapshot)
                == "Skipped remaining on Zone 2. Ready to finish."
        )
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "1 exercise still left on Zone 2 · 45 min."
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canSkipRemaining == false)
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "Zone 2 · 45 min is ready to finish."
        )
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "No next set. Zone 2 · 45 min is ready to finish."
        )
    }

    @Test func missingAndFinishedSessionsStayQuiet() {
        let missing = MoonstoneAskFitLog.querySnapshot(inProgress: nil, displayUnit: .pounds)
        #expect(missing.inProgressWorkoutName == nil)
        #expect(MoonstoneAskFitLog.canSkipRemaining(snapshot: missing) == false)
        #expect(MoonstoneAskFitLog.skipRemainingDialog(snapshot: missing) == MoonstoneAskFitLog.noInProgressDialog)
        #expect(MoonstoneAskFitLog.nextSetDialog(snapshot: missing) == MoonstoneAskFitLog.noInProgressDialog)
        #expect(MoonstoneAskFitLog.readyToFinishDialog(snapshot: missing) == MoonstoneAskFitLog.noInProgressDialog)

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
        let finishedSnapshot = MoonstoneAskFitLog.querySnapshot(
            inProgress: finished,
            displayUnit: .pounds
        )
        #expect(finishedSnapshot.canSkipRemaining == false)
        #expect(finishedSnapshot.isReadyToFinish == false)
        #expect(
            MoonstoneAskFitLog.skipRemainingDialog(snapshot: finishedSnapshot)
                == MoonstoneAskFitLog.noInProgressDialog
        )
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: finishedSnapshot)
                == MoonstoneAskFitLog.noInProgressDialog
        )
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: finishedSnapshot)
                == MoonstoneAskFitLog.noInProgressDialog
        )
    }

    @Test func openSlotPlaceholderCannotBeSkippedAndBlocksFinish() {
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
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.canSkipRemaining == false)
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.isReadyToFinish == false)
        #expect(MoonstoneAskFitLog.skipRemainingTarget(in: live, displayUnit: .pounds) == nil)
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
    }

    @Test func kilogramsCaptionUsesDisplayUnit() {
        let benchId = UUID()
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
                )
            ]
        )
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .kilograms)
        #expect(snapshot.skipCaption == "83.9 kg × 8 reps")
        #expect(snapshot.nextSetLastCaption == "83.9 kg × 8 reps")
        #expect(
            MoonstoneAskFitLog.nextSetDialog(snapshot: snapshot)
                == "Bench Press, set 2 of 3. Last was 83.9 kg × 8 reps."
        )
    }

    @Test func leftoverCountUsesPlural() {
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [
                ("Bench Press", UUID(), 3, nil, []),
                ("Incline Press", UUID(), 3, nil, [])
            ]
        )
        let snapshot = MoonstoneAskFitLog.querySnapshot(inProgress: live, displayUnit: .pounds)
        #expect(snapshot.remainingIncompleteCount == 2)
        #expect(
            MoonstoneAskFitLog.readyToFinishDialog(snapshot: snapshot)
                == "2 exercises still left on Push A."
        )
        #expect(snapshot.canSkipRemaining)
        #expect(snapshot.skipExerciseName == "Bench Press")
        #expect(snapshot.nextAfterSkipName == "Incline Press")
    }

    @Test func moonstoneSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.MoonstoneSessionSnapshot(
            inProgressWorkoutName: "Push A",
            skipExerciseName: "Bench Press",
            skipCaption: "185 lb × 8 reps",
            nextAfterSkipName: "Incline Press",
            nextAfterSkipCaption: "70 lb × 10 reps",
            canSkipRemaining: true,
            nextSetExerciseName: "Bench Press",
            nextSetNumber: 2,
            nextSetOf: 3,
            nextSetLastCaption: "185 lb × 8 reps",
            isCardioNextSet: false,
            remainingIncompleteCount: 2,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishMoonstoneSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadMoonstoneSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueSkipRemainingSets()
        #expect(FitLogIntentBridge.consumePendingSkipRemainingSets())
        #expect(FitLogIntentBridge.consumePendingSkipRemainingSets() == false)
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
