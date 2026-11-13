//
//  FluoriteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct FluoriteAskFitLogTests {

    @Test func previousTargetAndThisLastWorkingUseFocusedAndPreviousRows() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousIsCardio == false)
        #expect(snapshot.previousTargetCaption == "3 sets of 8-12")
        #expect(snapshot.focusedLastWorkingCaption == "155 lb × 10 reps")
        #expect(snapshot.canResetRest == false)
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Previous is Bench Press: 3 sets of 8-12."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Incline Press. Last was 155 lb × 10 reps."
        )
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot)
                == FluoriteAskFitLog.noRestTimerDialog
        )
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot) == false)
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete == false)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousTargetCaption == "4 sets of 10")
        #expect(snapshot.focusedLastWorkingCaption == "185 lb × 8 reps")
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Previous is Incline Press: 4 sets of 10."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Bench Press. Last was 185 lb × 8 reps."
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.focusedLastWorkingCaption == nil)
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Bench Press. No working set logged yet."
        )
    }

    @Test func cardioPreviousSpeaksDurationAndFocusedLastLoggedTime() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousIsCardio)
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.previousTargetCaption == "45 minutes")
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Previous is Zone 2: 45 minutes."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Bench Press. No working set logged yet."
        )
    }

    @Test func focusedCardioSpeaksLastDurationNotWeight() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedIsCardio)
        #expect(snapshot.focusedLastWorkingCaption == "42 minutes")
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Zone 2. Last was 42 minutes."
        )
    }

    @Test func resetRestWhenCountdownIsLiveAndBelowPrescribed() {
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
        let restEndsAt = now.addingTimeInterval(45)
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(snapshot.canResetRest)
        #expect(snapshot.focusedPrescribedRestSeconds == 90)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now))
        #expect(FluoriteAskFitLog.remainingRestSeconds(snapshot: snapshot, now: now) == 45)
        #expect(FluoriteAskFitLog.resetRestSeconds(snapshot: snapshot) == 90)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
    }

    @Test func resetRestFromAddedTimeGoesBackToPrescribed() {
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
        let restEndsAt = now.addingTimeInterval(200)
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: restEndsAt,
            now: now
        )
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now))
        #expect(FluoriteAskFitLog.resetRestSeconds(snapshot: snapshot) == 90)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func oneSecondRestCanStillResetInsteadOfSkipping() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canResetRest)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now))
        #expect(FluoriteAskFitLog.resetRestSeconds(snapshot: snapshot) == 90)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func alreadyAtPrescribedDoesNotQueueAReset() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(snapshot.canResetRest == false)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now) == false)
        #expect(FluoriteAskFitLog.resetRestSeconds(snapshot: snapshot) == 90)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == "Rest already at prescribed 1 minute, 30 seconds."
        )
    }

    @Test func sessionOverrideWinsOverPlanDefault() {
        let benchId = UUID()
        let workoutExercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: benchId,
                nameAtTimeOfLog: "Bench Press"
            )),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [workoutExercise]),
            startTime: Date().addingTimeInterval(-120),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: workoutExercise,
                    loggedSets: [],
                    sessionRestOverrideSeconds: 150
                )
            ],
            activeExerciseIds: [benchId]
        )
        let now = Date()
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedPrescribedRestSeconds == 150)
        #expect(FluoriteAskFitLog.resetRestSeconds(snapshot: snapshot) == 150)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now))
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 30 seconds."
        )
    }

    @Test func expiredRestDoesNotQueueAReset() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-1),
            now: now
        )
        #expect(snapshot.canResetRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now) == false)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == FluoriteAskFitLog.noRestTimerDialog
        )
    }

    @Test func idleRestOnInProgressDoesNotInventAStart() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot) == false)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot)
                == FluoriteAskFitLog.noRestTimerDialog
        )
    }

    @Test func focusedCardioDoesNotQueueARestReset() {
        let zone2Id = UUID()
        let live = session(
            name: "Zone 2",
            endedAt: nil,
            duration: 60,
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
        let now = Date()
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedIsCardio)
        #expect(snapshot.canResetRest == false)
        #expect(FluoriteAskFitLog.canResetRest(snapshot: snapshot, now: now) == false)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == "Zone 2 is cardio."
        )
    }

    @Test func nothingFocusedFallsThroughToLastIncompleteForPrevious() {
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
        let snapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousTargetCaption == "4 sets of 10")
        #expect(snapshot.canResetRest == false)
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Previous is Incline Press: 4 sets of 10."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == FluoriteAskFitLog.nothingFocusedDialog
        )
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot, now: now)
                == FluoriteAskFitLog.nothingFocusedDialog
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: nil)
                == FluoriteAskFitLog.noInProgressDialog
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: nil)
                == FluoriteAskFitLog.noInProgressDialog
        )
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: nil)
                == FluoriteAskFitLog.noInProgressDialog
        )
        #expect(FluoriteAskFitLog.canResetRest(snapshot: nil) == false)

        let empty = FluoriteAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canResetRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: empty)
                == FluoriteAskFitLog.noInProgressDialog
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
        let finishedSnapshot = FluoriteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canResetRest == false)
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: finishedSnapshot)
                == FluoriteAskFitLog.noInProgressDialog
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: finishedSnapshot)
                == FluoriteAskFitLog.noInProgressDialog
        )
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: finishedSnapshot)
                == FluoriteAskFitLog.noInProgressDialog
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.previousExerciseName == nil)
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "No previous exercise. Push A is ready to finish."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Bench Press. Last was 185 lb × 8 reps."
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
        let snapshot = FluoriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(
            FluoriteAskFitLog.previousExerciseTargetDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            FluoriteAskFitLog.thisExerciseLastWorkingDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            FluoriteAskFitLog.resetRestDialog(snapshot: snapshot)
                == FluoriteAskFitLog.noRestTimerDialog
        )
    }

    @Test func fluoriteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.FluoriteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsCardio: false,
            focusedIsIncomplete: true,
            focusedLastWorkingCaption: "155 lb × 10 reps",
            focusedPrescribedRestSeconds: 120,
            previousExerciseName: "Bench Press",
            previousIsCardio: false,
            previousTargetCaption: "3 sets of 8-12",
            canResetRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishFluoriteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadFluoriteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishFluoriteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadFluoriteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(FluoriteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishFluoriteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadFluoriteRestEndsAt() == nil)

        FitLogIntentBridge.queueResetRestTime()
        #expect(FitLogIntentBridge.consumePendingResetRestTime())
        #expect(FitLogIntentBridge.consumePendingResetRestTime() == false)
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
