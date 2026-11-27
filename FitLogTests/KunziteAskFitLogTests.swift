//
//  KunziteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct KunziteAskFitLogTests {

    @Test func lastWarmupRestIgnoresWorkingSetsAndSkipsCardio() {
        let benchId = UUID()
        let inclineId = UUID()
        let zone2Id = UUID()
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
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 150,
                            timestamp: Date().addingTimeInterval(-30),
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
                            reps: 10,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .warmup
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
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .warmup,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWarmupRestSeconds == 75)
        #expect(snapshot.lastWarmupRestExerciseName == "Incline Press")
        #expect(snapshot.warmupSetsLogged == 2)
        #expect(snapshot.canUseLastWarmupRest)
        #expect(KunziteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 75)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
        #expect(
            KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(snapshot: snapshot)
                == "Last warmup rest this workout was 1 minute, 15 seconds on Incline Press."
        )
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: snapshot)
                == "2 warmup sets logged this workout."
        )
    }

    @Test func workingOnlyDoesNotBorrowWorkingRestAsWarmup() {
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
                            restTime: 120,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == nil)
        #expect(snapshot.warmupSetsLogged == 0)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == KunziteAskFitLog.noWarmupRestDialog
        )
        #expect(
            KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(snapshot: snapshot)
                == KunziteAskFitLog.noWarmupRestDialog
        )
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: snapshot)
                == KunziteAskFitLog.noWarmupSetsDialog
        )
    }

    @Test func laterWarmupRestBeatsEarlierOnAnyRow() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    4,
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
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 75,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == 90)
        #expect(snapshot.lastWarmupRestExerciseName == "Incline Press")
        #expect(snapshot.warmupSetsLogged == 2)
        #expect(
            KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(snapshot: snapshot)
                == "Last warmup rest this workout was 1 minute, 30 seconds on Incline Press."
        )
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func idleAndExpiredRestDoNotInventAStart() {
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
                            restTime: 90,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let idle = KunziteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastWarmupRest == false)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: idle, now: now)
                == KunziteAskFitLog.noRestTimerDialog
        )
        #expect(
            KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(snapshot: idle)
                == "Last warmup rest this workout was 1 minute, 30 seconds on Bench Press."
        )
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: idle)
                == "1 warmup set logged this workout."
        )

        let expired = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastWarmupRest == false)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: expired, now: now)
                == KunziteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseLastWarmupRestWithoutStartingRest() {
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
                            restTime: 210,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastWarmupRest)
        #expect(KunziteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 210)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 3 minutes, 30 seconds."
        )
    }

    @Test func warmupRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
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
                            restTime: 900,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == 900)
        #expect(KunziteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseLastWarmupRest)
    }

    @Test func zeroWarmupRestSkipsThatSetForRestButStillCountsTheSet() {
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
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 115,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == 60)
        #expect(snapshot.warmupSetsLogged == 2)
        #expect(KunziteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 60)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: snapshot)
                == "2 warmup sets logged this workout."
        )
    }

    @Test func finishedAndMissingSessionsStayQuiet() {
        let benchId = UUID()
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 600,
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
                            weight: 95,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let finishedSnapshot = KunziteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastWarmupRest == false)
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: finishedSnapshot, now: now)
                == KunziteAskFitLog.noInProgressDialog
        )
        #expect(
            KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(snapshot: finishedSnapshot)
                == KunziteAskFitLog.noInProgressDialog
        )
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: finishedSnapshot)
                == KunziteAskFitLog.noInProgressDialog
        )

        let missing = KunziteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: missing)
                == KunziteAskFitLog.noInProgressDialog
        )
    }

    @Test func openPlaceholderDoesNotInventWarmupRestFromTheSlot() {
        let benchId = UUID()
        let flyId = UUID()
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
        let bench = workoutExercise("Bench Press", benchId, 3, "8", 90, nil)
        let fly = workoutExercise("Chest Fly", flyId, 3, "12", 60, nil)
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [bench, openSlot, fly]),
            startTime: Date().addingTimeInterval(-200),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: bench,
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 75,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: openSlot,
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: fly,
                    loggedSets: []
                )
            ],
            activeExerciseIds: [benchId]
        )
        let now = Date()
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.lastWarmupRestSeconds == nil)
        #expect(snapshot.warmupSetsLogged == 0)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
    }

    @Test func warmupRestStillAppliesWhenLaterRowsAreIncomplete() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            completedExerciseIds: [],
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
                            restTime: 45,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .warmup
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
        let snapshot = KunziteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.canUseLastWarmupRest)
        #expect(snapshot.warmupSetsLogged == 1)
        #expect(
            KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(snapshot: snapshot)
                == "1 warmup set logged this workout."
        )
        #expect(
            KunziteAskFitLog.useThisWorkoutLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 45 seconds."
        )
    }

    @Test func kunziteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.KunziteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsIncomplete: true,
            lastWarmupRestSeconds: 40,
            lastWarmupRestExerciseName: "Bench Press",
            warmupSetsLogged: 2,
            canUseLastWarmupRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishKunziteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadKunziteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishKunziteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadKunziteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(KunziteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishKunziteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadKunziteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseThisWorkoutLastWarmupRestTime()
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastWarmupRestTime())
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastWarmupRestTime() == false)
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
