//
//  ObsidianAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ObsidianAskFitLogTests {

    @Test func nextTargetAndLastWorkingUseNextIncompleteRow() {
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
                    "8-12",
                    90,
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
                    4,
                    "10",
                    120,
                    nil,
                    [
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
                            weight: 155,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextIsCardio == false)
        #expect(snapshot.nextTargetCaption == "4 sets of 10")
        #expect(snapshot.nextLastWorkingCaption == "155 lb × 10 reps")
        #expect(snapshot.canSubtractRest == false)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Next is Incline Press: 4 sets of 10."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "Next is Incline Press. Last was 155 lb × 10 reps."
        )
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot)
                == ObsidianAskFitLog.noRestTimerDialog
        )
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: snapshot) == false)
    }

    @Test func wrapToFirstIncompleteAndSkipWarmupOnlyLastWorking() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                (
                    "Incline Press",
                    inclineId,
                    3,
                    "10",
                    90,
                    nil,
                    [
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
                            weight: 135,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
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
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextTargetCaption == "3 sets of 8")
        #expect(snapshot.nextLastWorkingCaption == nil)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Next is Bench Press: 3 sets of 8."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "Next is Bench Press. No working set logged yet."
        )
    }

    @Test func alreadyOnOnlyLeftoverDoesNotWrapOntoSelf() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
    }

    @Test func cardioNextSpeaksDurationAndLastLoggedTime() {
        let benchId = UUID()
        let zone2Id = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                (
                    "Zone 2",
                    zone2Id,
                    1,
                    "—",
                    90,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    []
                )
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.nextIsCardio)
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextTargetCaption == "45 minutes")
        #expect(snapshot.nextLastWorkingCaption == nil)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Next is Zone 2: 45 minutes."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "Next is Zone 2. No working set logged yet."
        )
    }

    @Test func subtractRestWhenCountdownIsLive() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let restEndsAt = now.addingTimeInterval(90)
        let snapshot = ObsidianAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(snapshot.canSubtractRest)
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: snapshot, now: now))
        #expect(ObsidianAskFitLog.remainingRestSeconds(snapshot: snapshot, now: now) == 90)
        #expect(ObsidianAskFitLog.subtractedRestSeconds(snapshot: snapshot, now: now) == 60)
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
    }

    @Test func subtractRestFloorsAtOneSecondInsteadOfSkipping() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let restEndsAt = now.addingTimeInterval(20)
        let snapshot = ObsidianAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: snapshot, now: now))
        #expect(ObsidianAskFitLog.subtractedRestSeconds(snapshot: snapshot, now: now) == 1)
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 second."
        )
    }

    @Test func oneSecondRestDoesNotQueueASkip() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = ObsidianAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canSubtractRest == false)
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: snapshot, now: now) == false)
        #expect(ObsidianAskFitLog.subtractedRestSeconds(snapshot: snapshot, now: now) == nil)
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot, now: now)
                == ObsidianAskFitLog.restAlreadyMinimumDialog
        )
    }

    @Test func expiredRestDoesNotQueueLessTime() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = ObsidianAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-1),
            now: now
        )
        #expect(snapshot.canSubtractRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: snapshot, now: now) == false)
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot, now: now)
                == ObsidianAskFitLog.noRestTimerDialog
        )
    }

    @Test func idleRestOnInProgressDoesNotInventASkip() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: snapshot) == false)
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot)
                == ObsidianAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedFallsThroughToFirstIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = ObsidianAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextTargetCaption == "3 sets of 8")
        #expect(snapshot.canSubtractRest)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Next is Bench Press: 3 sets of 8."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "Next is Bench Press. No working set logged yet."
        )
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot, now: now)
                == "Rest now 40 seconds."
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: nil)
                == ObsidianAskFitLog.noInProgressDialog
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: nil)
                == ObsidianAskFitLog.noInProgressDialog
        )
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: nil)
                == ObsidianAskFitLog.noInProgressDialog
        )
        #expect(ObsidianAskFitLog.canSubtractRest(snapshot: nil) == false)

        let empty = ObsidianAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canSubtractRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: empty)
                == ObsidianAskFitLog.noInProgressDialog
        )

        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 3600,
            activeExerciseIds: [UUID()],
            exercises: [
                ("Bench Press", UUID(), 3, "8", 90, nil, [])
            ]
        )
        let finishedSnapshot = ObsidianAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canSubtractRest == false)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: finishedSnapshot)
                == ObsidianAskFitLog.noInProgressDialog
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: finishedSnapshot)
                == ObsidianAskFitLog.noInProgressDialog
        )
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: finishedSnapshot)
                == ObsidianAskFitLog.noInProgressDialog
        )
    }

    @Test func readyToFinishHasNoNextExercise() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 1800,
            activeExerciseIds: [benchId],
            completedExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
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
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "No next exercise. Push A is ready to finish."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "No next exercise. Push A is ready to finish."
        )
    }

    @Test func openSlotPlaceholderCannotBecomeATarget() {
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
                    loggedSets: []
                )
            ]
        )
        let snapshot = ObsidianAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            ObsidianAskFitLog.nextExerciseTargetDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            ObsidianAskFitLog.nextExerciseLastWorkingDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot)
                == ObsidianAskFitLog.noRestTimerDialog
        )
    }

    @Test func obsidianSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.ObsidianSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsIncomplete: true,
            nextExerciseName: "Incline Press",
            nextIsCardio: false,
            nextTargetCaption: "4 sets of 10",
            nextLastWorkingCaption: "155 lb × 10 reps",
            canSubtractRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishObsidianSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadObsidianSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishObsidianRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadObsidianRestEndsAt()
        #expect(loadedRest != nil)
        #expect(ObsidianAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishObsidianRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadObsidianRestEndsAt() == nil)

        FitLogIntentBridge.queueSubtractRestTime()
        #expect(FitLogIntentBridge.consumePendingSubtractRestTime())
        #expect(FitLogIntentBridge.consumePendingSubtractRestTime() == false)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        exercises: [(String, UUID, Int, String, Int, CardioPrescription?, [LoggedSet])]
    ) -> WorkoutSession {
        let logs: [ExerciseLog] = exercises.map { exerciseName, exerciseId, recommendedSets, recommendedReps, rest, cardio, sets in
            let workoutExercise = WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: exerciseId,
                    nameAtTimeOfLog: exerciseName
                )),
                defaultRestTime: rest,
                recommendedSets: recommendedSets,
                recommendedReps: recommendedReps,
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
            exerciseLogs: logs,
            activeExerciseIds: activeExerciseIds,
            completedExerciseIds: completedExerciseIds
        )
    }
}
