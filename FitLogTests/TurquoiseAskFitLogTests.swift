//
//  TurquoiseAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct TurquoiseAskFitLogTests {

    @Test func previousLastRestAndNextPrescribedRestUseNeighborRows() {
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
        let now = Date()
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousIsCardio == false)
        #expect(snapshot.previousLastRestSeconds == 90)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextPrescribedRestSeconds == 90)
        #expect(snapshot.canUsePreviousLastRest)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 1 minute, 30 seconds."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 1 minute, 30 seconds on Bench Press."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
        #expect(TurquoiseAskFitLog.previousLastRestTargetSeconds(snapshot: snapshot) == 90)
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
        let snapshot = TurquoiseAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousLastRestSeconds == 120)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextPrescribedRestSeconds == 120)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Incline Press was 2 minutes."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 2 minutes on Incline Press."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot)
                == TurquoiseAskFitLog.noRestTimerDialog
        )
        #expect(TurquoiseAskFitLog.canUsePreviousLastRest(snapshot: snapshot) == false)
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
        let now = Date()
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(45),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUsePreviousLastRest == false)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "Already on Bench Press."
        )
    }

    @Test func cardioPreviousHasNoLastRestAndNextCardioHasNoPrescription() {
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
        let now = Date()
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(50),
            now: now
        )
        #expect(snapshot.previousIsCardio)
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.previousLastRestSeconds == nil)
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextIsCardio)
        #expect(snapshot.nextPrescribedRestSeconds == nil)
        #expect(snapshot.canUsePreviousLastRest == false)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Zone 2."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Zone 2 is cardio."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "No rest logged yet on Zone 2."
        )
    }

    @Test func sessionRestOverrideWinsOverLibraryDefaultOnNext() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            sessionRestOverrideByExerciseId: [inclineId: 45],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = TurquoiseAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextPrescribedRestSeconds == 45)
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 45 seconds on Incline Press."
        )
    }

    @Test func warmupLastRestCountsOnPreviousRow() {
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
                            weight: 95,
                            reps: 8,
                            restTime: 40,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 150, nil, [])
            ]
        )
        let snapshot = TurquoiseAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousLastRestSeconds == 40)
        #expect(snapshot.nextPrescribedRestSeconds == 90)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 40 seconds."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 1 minute, 30 seconds on Bench Press."
        )
    }

    @Test func remainingOneSecondCanUsePreviousLastRestWithoutStartingRest() {
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
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUsePreviousLastRest)
        #expect(TurquoiseAskFitLog.previousLastRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func lastRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
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
                            restTime: 720,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(TurquoiseAskFitLog.previousLastRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
    }

    @Test func expiredRestDoesNotInventAStart() {
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
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(snapshot.canUsePreviousLastRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == TurquoiseAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedFallsThroughToLastIncompletePreviousLastRest() {
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
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousLastRestSeconds == 75)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextPrescribedRestSeconds == 90)
        #expect(snapshot.canUsePreviousLastRest)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Incline Press was 1 minute, 15 seconds."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 1 minute, 30 seconds on Bench Press."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: nil)
                == TurquoiseAskFitLog.noInProgressDialog
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: nil)
                == TurquoiseAskFitLog.noInProgressDialog
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: nil)
                == TurquoiseAskFitLog.noInProgressDialog
        )
        #expect(TurquoiseAskFitLog.canUsePreviousLastRest(snapshot: nil) == false)

        let empty = TurquoiseAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canUsePreviousLastRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: empty)
                == TurquoiseAskFitLog.noInProgressDialog
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
        let finishedSnapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUsePreviousLastRest == false)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: finishedSnapshot)
                == TurquoiseAskFitLog.noInProgressDialog
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: finishedSnapshot)
                == TurquoiseAskFitLog.noInProgressDialog
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: finishedSnapshot)
                == TurquoiseAskFitLog.noInProgressDialog
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
        let snapshot = TurquoiseAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUsePreviousLastRest == false)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "No previous exercise. Push A is ready to finish."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "No next exercise. Push A is ready to finish."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot, now: now)
                == "No previous exercise. Push A is ready to finish."
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
        let snapshot = TurquoiseAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(
            TurquoiseAskFitLog.previousExerciseLastRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            TurquoiseAskFitLog.nextExercisePrescribedRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            TurquoiseAskFitLog.usePreviousLastRestDialog(snapshot: snapshot)
                == TurquoiseAskFitLog.noRestTimerDialog
        )
    }

    @Test func turquoiseSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.TurquoiseSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsCardio: false,
            focusedIsIncomplete: true,
            previousExerciseName: "Bench Press",
            previousIsCardio: false,
            previousLastRestSeconds: 90,
            nextExerciseName: "Flyes",
            nextIsCardio: false,
            nextPrescribedRestSeconds: 120,
            canUsePreviousLastRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishTurquoiseSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadTurquoiseSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishTurquoiseRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadTurquoiseRestEndsAt()
        #expect(loadedRest != nil)
        #expect(TurquoiseAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishTurquoiseRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadTurquoiseRestEndsAt() == nil)

        FitLogIntentBridge.queueUsePreviousLastRestTime()
        #expect(FitLogIntentBridge.consumePendingUsePreviousLastRestTime())
        #expect(FitLogIntentBridge.consumePendingUsePreviousLastRestTime() == false)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        sessionRestOverrideByExerciseId: [UUID: Int] = [:],
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
                loggedSets: sets,
                sessionRestOverrideSeconds: sessionRestOverrideByExerciseId[exerciseId]
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
