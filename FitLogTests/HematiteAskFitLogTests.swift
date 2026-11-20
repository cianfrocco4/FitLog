//
//  HematiteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct HematiteAskFitLogTests {

    @Test func previousPrescribedUsesPlanRestNotLoggedRestOrFocused() {
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
                    "8",
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 80,
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
                    90,
                    nil,
                    []
                )
            ]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousPrescribedRestSeconds == 150)
        #expect(snapshot.focusedLastRestSeconds == nil)
        #expect(snapshot.completedExerciseCount == 0)
        #expect(snapshot.canUsePreviousPrescribedRest)
        #expect(HematiteAskFitLog.previousPrescribedRestTargetSeconds(snapshot: snapshot) == 150)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 30 seconds."
        )
        #expect(
            HematiteAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Incline Press."
        )
        #expect(
            HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(snapshot: snapshot)
                == "No exercises done this workout."
        )
    }

    @Test func sessionOverrideWinsOverLibraryDefault() {
        let benchId = UUID()
        let inclineId = UUID()
        let bench = workoutExercise("Bench Press", benchId, 3, "8", 90, nil)
        let incline = workoutExercise("Incline Press", inclineId, 4, "10", 120, nil)
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [bench, incline]),
            startTime: Date().addingTimeInterval(-200),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: bench,
                    loggedSets: [],
                    sessionRestOverrideSeconds: 45
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: incline,
                    loggedSets: []
                )
            ],
            activeExerciseIds: [inclineId]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(30),
            now: now
        )
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousPrescribedRestSeconds == 45)
        #expect(HematiteAskFitLog.previousPrescribedRestTargetSeconds(snapshot: snapshot) == 45)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 45 seconds."
        )
    }

    @Test func previousPrescribedWrapsAndDoesNotWrapOntoTheOnlyLeftover() {
        let flyesId = UUID()
        let benchId = UUID()
        let inclineId = UUID()
        let wrapping = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, []),
                ("Flyes", flyesId, 3, "12", 75, nil, [])
            ]
        )
        let now = Date()
        let wrapSnapshot = HematiteAskFitLog.querySnapshot(
            inProgress: wrapping,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(wrapSnapshot.focusedExerciseName == "Bench Press")
        #expect(wrapSnapshot.previousExerciseName == "Flyes")
        #expect(wrapSnapshot.previousPrescribedRestSeconds == 75)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: wrapSnapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )

        let onlyLeftover = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 150, nil, [])
            ]
        )
        let onlySnapshot = HematiteAskFitLog.querySnapshot(
            inProgress: onlyLeftover,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(onlySnapshot.previousExerciseName == nil)
        #expect(onlySnapshot.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: onlySnapshot, now: now)
                == "Already on Bench Press."
        )
    }

    @Test func focusedLastRestUsesWarmupAndIgnoresZeroSecondCardio() {
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
                            weight: 95,
                            reps: 8,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = HematiteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedLastRestSeconds == 40)
        #expect(
            HematiteAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "Last rest on Bench Press was 40 seconds."
        )
    }

    @Test func idleAndExpiredRestDoNotInventAStart() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 150, nil, []),
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let idle = HematiteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: idle, now: now)
                == HematiteAskFitLog.noRestTimerDialog
        )
        #expect(
            HematiteAskFitLog.thisExerciseLastRestDialog(snapshot: idle)
                == "No rest logged yet on Incline Press."
        )

        let expired = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: expired, now: now)
                == HematiteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUsePreviousPrescribedWithoutStartingRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUsePreviousPrescribedRest)
        #expect(HematiteAskFitLog.previousPrescribedRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func prescribedRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 900, nil, []),
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.previousPrescribedRestSeconds == 900)
        #expect(HematiteAskFitLog.previousPrescribedRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUsePreviousPrescribedRest)
    }

    @Test func zeroPrescribedRestDoesNotBecomeATarget() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 0, nil, []),
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousPrescribedRestSeconds == nil)
        #expect(snapshot.canUsePreviousPrescribedRest == false)
        #expect(HematiteAskFitLog.previousPrescribedRestTargetSeconds(snapshot: snapshot) == nil)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "No rest prescription on Bench Press."
        )
    }

    @Test func cardioPreviousDoesNotInventARestChange() {
        let zone2Id = UUID()
        let benchId = UUID()
        let live = session(
            name: "Hybrid",
            endedAt: nil,
            duration: 200,
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
                ("Bench Press", benchId, 3, "8", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.previousIsCardio)
        #expect(snapshot.previousPrescribedRestSeconds == nil)
        #expect(snapshot.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Zone 2 is cardio."
        )
    }

    @Test func finishedAndMissingSessionsStayQuiet() {
        let benchId = UUID()
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 600,
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
        let finishedSnapshot = HematiteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: finishedSnapshot, now: now)
                == HematiteAskFitLog.noInProgressDialog
        )
        #expect(
            HematiteAskFitLog.thisExerciseLastRestDialog(snapshot: finishedSnapshot)
                == HematiteAskFitLog.noInProgressDialog
        )
        #expect(
            HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(snapshot: finishedSnapshot)
                == HematiteAskFitLog.noInProgressDialog
        )

        let missing = HematiteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(snapshot: missing)
                == HematiteAskFitLog.noInProgressDialog
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
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.completedExerciseCount == 0)
        #expect(snapshot.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            HematiteAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
    }

    @Test func completedExercisesCountMarkedCompleteAndLoggedRows() {
        let benchId = UUID()
        let inclineId = UUID()
        let flyesId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [flyesId],
            completedExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                (
                    "Incline Press",
                    inclineId,
                    2,
                    "10",
                    120,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 10,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 70,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ("Flyes", flyesId, 3, "12", 75, nil, [])
            ]
        )
        let snapshot = HematiteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.completedExerciseCount == 2)
        #expect(snapshot.focusedExerciseName == "Flyes")
        #expect(snapshot.previousExerciseName == nil)
        #expect(
            HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(snapshot: snapshot)
                == "2 exercises done this workout."
        )
        #expect(
            HematiteAskFitLog.thisExerciseLastRestDialog(snapshot: snapshot)
                == "No rest logged yet on Flyes."
        )
    }

    @Test func readyToFinishSpeaksAllExercisesDone() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            completedExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = HematiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.completedExerciseCount == 1)
        #expect(snapshot.canUsePreviousPrescribedRest == false)
        #expect(
            HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(snapshot: snapshot)
                == "All exercises done this workout."
        )
        #expect(
            HematiteAskFitLog.usePreviousPrescribedRestDialog(snapshot: snapshot, now: now)
                == "No previous exercise. Push A is ready to finish."
        )
    }

    @Test func hematiteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.HematiteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsIncomplete: true,
            focusedLastRestSeconds: 80,
            previousExerciseName: "Bench Press",
            previousIsCardio: false,
            previousPrescribedRestSeconds: 150,
            completedExerciseCount: 1,
            canUsePreviousPrescribedRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishHematiteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadHematiteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishHematiteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadHematiteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(HematiteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishHematiteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadHematiteRestEndsAt() == nil)

        FitLogIntentBridge.queueUsePreviousPrescribedRestTime()
        #expect(FitLogIntentBridge.consumePendingUsePreviousPrescribedRestTime())
        #expect(FitLogIntentBridge.consumePendingUsePreviousPrescribedRestTime() == false)
    }

    // MARK: - Fixtures

    private func workoutExercise(
        _ name: String,
        _ exerciseId: UUID,
        _ recommendedSets: Int,
        _ recommendedReps: String,
        _ rest: Int,
        _ cardio: CardioPrescription?
    ) -> WorkoutExercise {
        WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: exerciseId,
                nameAtTimeOfLog: name
            )),
            defaultRestTime: rest,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            cardioPrescription: cardio
        )
    }

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        exercises: [(String, UUID, Int, String, Int, CardioPrescription?, [LoggedSet])]
    ) -> WorkoutSession {
        let logs: [ExerciseLog] = exercises.map { exerciseName, exerciseId, recommendedSets, recommendedReps, rest, cardio, sets in
            ExerciseLog(
                id: UUID(),
                workoutExercise: workoutExercise(
                    exerciseName,
                    exerciseId,
                    recommendedSets,
                    recommendedReps,
                    rest,
                    cardio
                ),
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
