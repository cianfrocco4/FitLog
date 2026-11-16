//
//  CoralAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct CoralAskFitLogTests {

    @Test func previousRemainingAndNextLastRestUseNeighborRows() {
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
                            restTime: 75,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = CoralAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.focusedLastRestSeconds == 75)
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousIsCardio == false)
        #expect(snapshot.previousRemainingSetCount == 2)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextLastRestSeconds == 90)
        #expect(snapshot.canUseLastRest == false)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "2 sets left on Bench Press."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 1 minute, 30 seconds."
        )
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot)
                == CoralAskFitLog.noRestTimerDialog
        )
        #expect(CoralAskFitLog.canUseLastRest(snapshot: snapshot) == false)
    }

    @Test func wrapToLastIncompleteAndSkipZeroSecondRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
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
                            restTime: 0,
                            timestamp: Date(),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 155,
                            reps: 10,
                            restTime: 120,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = CoralAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousRemainingSetCount == 3)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextLastRestSeconds == 120)
        #expect(snapshot.focusedLastRestSeconds == nil)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Incline Press."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Incline Press was 2 minutes."
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
        let snapshot = CoralAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.focusedLastRestSeconds == nil)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
    }

    @Test func cardioPreviousSpeaksRemainingDurationAndNextLastRest() {
        let zone2Id = UUID()
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Zone 2",
                    zone2Id,
                    1,
                    "—",
                    90,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    []
                ),
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
                        )
                    ]
                )
            ]
        )
        let snapshot = CoralAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousIsCardio)
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.previousRemainingSetCount == 1)
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextLastRestSeconds == nil)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Zone 2 still needs a duration."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Zone 2."
        )
    }

    @Test func focusedCardioUsesLastRestWithoutInventingDuration() {
        let zone2Id = UUID()
        let live = session(
            name: "Zone 2",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [zone2Id],
            exercises: [
                (
                    "Zone 2",
                    zone2Id,
                    1,
                    "—",
                    90,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 42 * 60)
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(snapshot.focusedIsCardio)
        #expect(snapshot.focusedLastRestSeconds == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUseLastRest == false)
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == "No rest logged yet on Zone 2."
        )
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "No previous exercise. Zone 2 is ready to finish."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "No next exercise. Zone 2 is ready to finish."
        )
    }

    @Test func oneSetLeftOnPreviousStrengthRow() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
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
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = CoralAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousRemainingSetCount == 1)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "1 set left on Bench Press."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 1 minute, 30 seconds."
        )
    }

    @Test func useLastRestWhenCountdownIsLive() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
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
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let restEndsAt = now.addingTimeInterval(45)
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(snapshot.canUseLastRest)
        #expect(CoralAskFitLog.canUseLastRest(snapshot: snapshot, now: now))
        #expect(CoralAskFitLog.lastRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func remainingOneSecondCanUseLastRestWithoutStartingRest() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
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
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastRest)
        #expect(CoralAskFitLog.lastRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func lastRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
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
                            restTime: 720,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(CoralAskFitLog.lastRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
    }

    @Test func expiredRestDoesNotInventAStart() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
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
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(snapshot.canUseLastRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == CoralAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedFallsThroughToLastIncompleteRemainingSets() {
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [],
            exercises: [
                ("Bench Press", UUID(), 3, "8", 90, nil, []),
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
                            weight: 155,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousRemainingSetCount == 3)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextLastRestSeconds == nil)
        #expect(snapshot.canUseLastRest == false)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Incline Press."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Bench Press."
        )
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == CoralAskFitLog.nothingFocusedDialog
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: nil)
                == CoralAskFitLog.noInProgressDialog
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: nil)
                == CoralAskFitLog.noInProgressDialog
        )
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: nil)
                == CoralAskFitLog.noInProgressDialog
        )
        #expect(CoralAskFitLog.canUseLastRest(snapshot: nil) == false)

        let empty = CoralAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canUseLastRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: empty)
                == CoralAskFitLog.noInProgressDialog
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
        let finishedSnapshot = CoralAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastRest == false)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: finishedSnapshot)
                == CoralAskFitLog.noInProgressDialog
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: finishedSnapshot)
                == CoralAskFitLog.noInProgressDialog
        )
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: finishedSnapshot)
                == CoralAskFitLog.noInProgressDialog
        )
    }

    @Test func readyToFinishHasNoPreviousOrNextExercise() {
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
                            restTime: 75,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = CoralAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.focusedLastRestSeconds == 75)
        #expect(snapshot.canUseLastRest)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "No previous exercise. Push A is ready to finish."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "No next exercise. Push A is ready to finish."
        )
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
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
        let snapshot = CoralAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            CoralAskFitLog.previousExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            CoralAskFitLog.nextExerciseLastRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            CoralAskFitLog.useLastRestDialog(snapshot: snapshot)
                == CoralAskFitLog.noRestTimerDialog
        )
    }

    @Test func coralSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.CoralSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsCardio: false,
            focusedIsIncomplete: true,
            focusedLastRestSeconds: 75,
            previousExerciseName: "Bench Press",
            previousIsCardio: false,
            previousRemainingSetCount: 2,
            nextExerciseName: "Flyes",
            nextIsCardio: false,
            nextLastRestSeconds: 90,
            canUseLastRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishCoralSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadCoralSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishCoralRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadCoralRestEndsAt()
        #expect(loadedRest != nil)
        #expect(CoralAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishCoralRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadCoralRestEndsAt() == nil)

        FitLogIntentBridge.queueUseLastRestTime()
        #expect(FitLogIntentBridge.consumePendingUseLastRestTime())
        #expect(FitLogIntentBridge.consumePendingUseLastRestTime() == false)
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
