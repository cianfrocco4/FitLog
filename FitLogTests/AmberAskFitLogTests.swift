//
//  AmberAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct AmberAskFitLogTests {

    @Test func nextRemainingAndThisLastRestUseFocusedAndNextRows() {
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
                            restTime: 75,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedLastRestSeconds == 90)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextIsCardio == false)
        #expect(snapshot.nextRemainingSetCount == 3)
        #expect(snapshot.canDoubleRest == false)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Incline Press."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 90 seconds."
        )
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot)
                == AmberAskFitLog.noRestTimerDialog
        )
        #expect(AmberAskFitLog.canDoubleRest(snapshot: snapshot) == false)
    }

    @Test func wrapToFirstIncompleteAndSkipZeroSecondRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
            activeExerciseIds: [inclineId],
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
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextRemainingSetCount == 3)
        #expect(snapshot.focusedLastRestSeconds == 120)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Bench Press."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
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
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.focusedLastRestSeconds == nil)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Bench Press."
        )
    }

    @Test func cardioNextSpeaksRemainingDurationAndFocusedLastRest() {
        let benchId = UUID()
        let zone2Id = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
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
                ),
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
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.nextIsCardio)
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextRemainingSetCount == 1)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Zone 2 still needs a duration."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 90 seconds."
        )
    }

    @Test func focusedCardioSpeaksLastRestWithoutInventingDuration() {
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
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedIsCardio)
        #expect(snapshot.focusedLastRestSeconds == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Zone 2."
        )
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "No next exercise. Zone 2 is ready to finish."
        )
    }

    @Test func oneSetLeftOnNextStrengthRow() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                (
                    "Incline Press",
                    inclineId,
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 155,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 155,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.nextRemainingSetCount == 1)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "1 set left on Incline Press."
        )
    }

    @Test func doubleRestWhenCountdownIsLiveAndBelowCap() {
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
        let snapshot = AmberAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(snapshot.canDoubleRest)
        #expect(AmberAskFitLog.canDoubleRest(snapshot: snapshot, now: now))
        #expect(AmberAskFitLog.doubledRestSeconds(snapshot: snapshot, now: now) == 180)
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot, now: now)
                == "Rest now 3 minutes."
        )
    }

    @Test func remainingOneSecondCanDoubleWithoutStartingRest() {
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
        let snapshot = AmberAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canDoubleRest)
        #expect(AmberAskFitLog.doubledRestSeconds(snapshot: snapshot, now: now) == 2)
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 seconds."
        )
    }

    @Test func doublingPastCapStopsAtTenMinutesAndDoesNotSkip() {
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
        let snapshot = AmberAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(350),
            now: now
        )
        #expect(AmberAskFitLog.doubledRestSeconds(snapshot: snapshot, now: now) == 600)
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
    }

    @Test func remainingAtCapCannotDouble() {
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
        let snapshot = AmberAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(600),
            now: now
        )
        #expect(snapshot.canDoubleRest == false)
        #expect(AmberAskFitLog.canDoubleRest(snapshot: snapshot, now: now) == false)
        #expect(AmberAskFitLog.doubledRestSeconds(snapshot: snapshot, now: now) == nil)
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot, now: now)
                == AmberAskFitLog.restAlreadyMaximumDialog
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
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = AmberAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(snapshot.canDoubleRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot, now: now)
                == AmberAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedFallsThroughToFirstIncompleteRemainingSets() {
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [],
            exercises: [
                ("Bench Press", UUID(), 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = AmberAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextRemainingSetCount == 3)
        #expect(snapshot.canDoubleRest)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Bench Press."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == AmberAskFitLog.nothingFocusedDialog
        )
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 20 seconds."
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: nil)
                == AmberAskFitLog.noInProgressDialog
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: nil)
                == AmberAskFitLog.noInProgressDialog
        )
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: nil)
                == AmberAskFitLog.noInProgressDialog
        )
        #expect(AmberAskFitLog.canDoubleRest(snapshot: nil) == false)

        let empty = AmberAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canDoubleRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: empty)
                == AmberAskFitLog.noInProgressDialog
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
        let finishedSnapshot = AmberAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canDoubleRest == false)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: finishedSnapshot)
                == AmberAskFitLog.noInProgressDialog
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: finishedSnapshot)
                == AmberAskFitLog.noInProgressDialog
        )
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: finishedSnapshot)
                == AmberAskFitLog.noInProgressDialog
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
                            restTime: 75,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.focusedLastRestSeconds == 75)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "No next exercise. Push A is ready to finish."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 1 minute, 15 seconds."
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
        let snapshot = AmberAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            AmberAskFitLog.nextExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            AmberAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            AmberAskFitLog.doubleRestDialog(snapshot: snapshot)
                == AmberAskFitLog.noRestTimerDialog
        )
    }

    @Test func amberSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.AmberSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsCardio: false,
            focusedIsIncomplete: true,
            focusedLastRestSeconds: 90,
            nextExerciseName: "Incline Press",
            nextIsCardio: false,
            nextRemainingSetCount: 3,
            canDoubleRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishAmberSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadAmberSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishAmberRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadAmberRestEndsAt()
        #expect(loadedRest != nil)
        #expect(AmberAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishAmberRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadAmberRestEndsAt() == nil)

        FitLogIntentBridge.queueDoubleRestTime()
        #expect(FitLogIntentBridge.consumePendingDoubleRestTime())
        #expect(FitLogIntentBridge.consumePendingDoubleRestTime() == false)
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
