//
//  JadeAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct JadeAskFitLogTests {

    @Test func previousLastWorkingAndThisRemainingUseFocusedAndPreviousRows() {
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
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousIsCardio == false)
        #expect(snapshot.previousLastWorkingCaption == "185 lb × 8 reps")
        #expect(snapshot.focusedRemainingSetCount == 3)
        #expect(snapshot.canHalveRest == false)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "Previous is Bench Press. Last was 185 lb × 8 reps."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Incline Press."
        )
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot)
                == JadeAskFitLog.noRestTimerDialog
        )
        #expect(JadeAskFitLog.canHalveRest(snapshot: snapshot) == false)
    }

    @Test func wrapToLastIncompleteAndSkipWarmupOnlyLastWorking() {
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
                ),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete == false)
        #expect(snapshot.focusedRemainingSetCount == 0)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousLastWorkingCaption == nil)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "Previous is Incline Press. No working set logged yet."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "No sets left on Bench Press."
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
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.focusedRemainingSetCount == 3)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Bench Press."
        )
    }

    @Test func cardioPreviousSpeaksLastDurationAndFocusedRemainingSets() {
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
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 40 * 60)
                        )
                    ]
                ),
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousIsCardio)
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.previousLastWorkingCaption == "40 minutes")
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "Previous is Zone 2. Last was 40 minutes."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "3 sets left on Bench Press."
        )
    }

    @Test func focusedCardioSpeaksRemainingDurationNotWeight() {
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
                    []
                )
            ]
        )
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedIsCardio)
        #expect(snapshot.focusedRemainingSetCount == 1)
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Zone 2 still needs a duration."
        )

        let logged = session(
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
        let loggedSnapshot = JadeAskFitLog.querySnapshot(inProgress: logged, restEndsAt: nil)
        #expect(loggedSnapshot.focusedRemainingSetCount == 0)
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: loggedSnapshot)
                == "No duration left on Zone 2."
        )
    }

    @Test func oneSetLeftOnFocusedStrengthRow() {
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
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedRemainingSetCount == 1)
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "1 set left on Bench Press."
        )
    }

    @Test func halveRestWhenCountdownIsLiveAndAboveOneSecond() {
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
        let snapshot = JadeAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(snapshot.canHalveRest)
        #expect(JadeAskFitLog.canHalveRest(snapshot: snapshot, now: now))
        #expect(JadeAskFitLog.halvedRestSeconds(snapshot: snapshot, now: now) == 45)
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot, now: now)
                == "Rest now 45 seconds."
        )
    }

    @Test func oddRemainingRestFloorsAndDoesNotSkip() {
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
        let snapshot = JadeAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(45),
            now: now
        )
        #expect(JadeAskFitLog.halvedRestSeconds(snapshot: snapshot, now: now) == 22)
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot, now: now)
                == "Rest now 22 seconds."
        )
    }

    @Test func remainingOneSecondCannotHalveIntoASkip() {
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
        let snapshot = JadeAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canHalveRest == false)
        #expect(JadeAskFitLog.canHalveRest(snapshot: snapshot, now: now) == false)
        #expect(JadeAskFitLog.halvedRestSeconds(snapshot: snapshot, now: now) == nil)
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot, now: now)
                == JadeAskFitLog.restAlreadyMinimumDialog
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
        let snapshot = JadeAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(snapshot.canHalveRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot, now: now)
                == JadeAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedFallsThroughToLastIncompleteLastWorking() {
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
        let snapshot = JadeAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousLastWorkingCaption == nil)
        #expect(snapshot.canHalveRest)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "Previous is Incline Press. No working set logged yet."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == JadeAskFitLog.nothingFocusedDialog
        )
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot, now: now)
                == "Rest now 35 seconds."
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: nil)
                == JadeAskFitLog.noInProgressDialog
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: nil)
                == JadeAskFitLog.noInProgressDialog
        )
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: nil)
                == JadeAskFitLog.noInProgressDialog
        )
        #expect(JadeAskFitLog.canHalveRest(snapshot: nil) == false)

        let empty = JadeAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canHalveRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: empty)
                == JadeAskFitLog.noInProgressDialog
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
        let finishedSnapshot = JadeAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canHalveRest == false)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: finishedSnapshot)
                == JadeAskFitLog.noInProgressDialog
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: finishedSnapshot)
                == JadeAskFitLog.noInProgressDialog
        )
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: finishedSnapshot)
                == JadeAskFitLog.noInProgressDialog
        )
    }

    @Test func readyToFinishHasNoPreviousExercise() {
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
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.focusedRemainingSetCount == 0)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "No previous exercise. Push A is ready to finish."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "No sets left on Bench Press."
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
        let snapshot = JadeAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(
            JadeAskFitLog.previousExerciseLastWorkingDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            JadeAskFitLog.thisExerciseRemainingSetsDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            JadeAskFitLog.halveRestDialog(snapshot: snapshot)
                == JadeAskFitLog.noRestTimerDialog
        )
    }

    @Test func jadeSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.JadeSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsCardio: false,
            focusedIsIncomplete: true,
            focusedRemainingSetCount: 3,
            previousExerciseName: "Bench Press",
            previousIsCardio: false,
            previousLastWorkingCaption: "185 lb × 8 reps",
            canHalveRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishJadeSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadJadeSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishJadeRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadJadeRestEndsAt()
        #expect(loadedRest != nil)
        #expect(JadeAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishJadeRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadJadeRestEndsAt() == nil)

        FitLogIntentBridge.queueHalveRestTime()
        #expect(FitLogIntentBridge.consumePendingHalveRestTime())
        #expect(FitLogIntentBridge.consumePendingHalveRestTime() == false)
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
