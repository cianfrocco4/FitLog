//
//  MalachiteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct MalachiteAskFitLogTests {

    @Test func nextPrescribedUsesPlanRestNotLoggedRestOrFocused() {
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
                    "8",
                    90,
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
                    150,
                    nil,
                    []
                )
            ]
        )
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextPrescribedRestSeconds == 150)
        #expect(snapshot.lastCompletedExerciseName == nil)
        #expect(snapshot.completedSetCount == 1)
        #expect(snapshot.canUseNextPrescribedRest)
        #expect(MalachiteAskFitLog.nextPrescribedRestTargetSeconds(snapshot: snapshot) == 150)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 30 seconds."
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(snapshot: snapshot)
                == "No rest prescription this workout."
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: snapshot)
                == "1 set done this workout."
        )
    }

    @Test func sessionOverrideWinsOverLibraryDefaultOnNextAndLastCompleted() {
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
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 80,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 80,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 80,
                            timestamp: Date(),
                            setType: .working
                        )
                    ],
                    sessionRestOverrideSeconds: 45
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: incline,
                    loggedSets: [],
                    sessionRestOverrideSeconds: 75
                )
            ],
            activeExerciseIds: [inclineId],
            completedExerciseIds: [benchId]
        )
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(30),
            now: now
        )
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.lastCompletedExerciseName == "Bench Press")
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 45)
        #expect(
            MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(snapshot: snapshot)
                == "Last prescribed rest this workout was 45 seconds on Bench Press."
        )
        #expect(snapshot.completedSetCount == 3)
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: snapshot)
                == "3 sets done this workout."
        )
        #expect(snapshot.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Already on Incline Press."
        )
    }

    @Test func nextPrescribedWrapsAndDoesNotWrapOntoTheOnlyLeftover() {
        let flyesId = UUID()
        let benchId = UUID()
        let inclineId = UUID()
        let wrapping = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [flyesId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, []),
                ("Flyes", flyesId, 3, "12", 75, nil, [])
            ]
        )
        let now = Date()
        let wrapSnapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: wrapping,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(wrapSnapshot.focusedExerciseName == "Flyes")
        #expect(wrapSnapshot.nextExerciseName == "Bench Press")
        #expect(wrapSnapshot.nextPrescribedRestSeconds == 90)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: wrapSnapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
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
        let onlySnapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: onlyLeftover,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(onlySnapshot.nextExerciseName == nil)
        #expect(onlySnapshot.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: onlySnapshot, now: now)
                == "Already on Bench Press."
        )
    }

    @Test func lastPrescribedSkipsCardioCompletedAndWarmupsDoNotCountAsSets() {
        let zone2Id = UUID()
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Hybrid",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [zone2Id, benchId],
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
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                ),
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
                            weight: 95,
                            reps: 8,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-15),
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
                ("Incline Press", inclineId, 4, "10", 75, nil, [])
            ]
        )
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.lastCompletedExerciseName == "Bench Press")
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 150)
        #expect(snapshot.completedSetCount == 4)
        #expect(
            MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(snapshot: snapshot)
                == "Last prescribed rest this workout was 2 minutes, 30 seconds on Bench Press."
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: snapshot)
                == "4 sets done this workout."
        )
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Already on Incline Press."
        )
    }

    @Test func idleAndExpiredRestDoNotInventAStart() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 150, nil, [])
            ]
        )
        let now = Date()
        let idle = MalachiteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: idle, now: now)
                == MalachiteAskFitLog.noRestTimerDialog
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: idle)
                == "No sets done this workout."
        )

        let expired = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: expired, now: now)
                == MalachiteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseNextPrescribedWithoutStartingRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseNextPrescribedRest)
        #expect(MalachiteAskFitLog.nextPrescribedRestTargetSeconds(snapshot: snapshot) == 120)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes."
        )
    }

    @Test func prescribedRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 900, nil, [])
            ]
        )
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.nextPrescribedRestSeconds == 900)
        #expect(MalachiteAskFitLog.nextPrescribedRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseNextPrescribedRest)
    }

    @Test func zeroPrescribedRestDoesNotBecomeATarget() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 0, nil, [])
            ]
        )
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextPrescribedRestSeconds == nil)
        #expect(snapshot.canUseNextPrescribedRest == false)
        #expect(MalachiteAskFitLog.nextPrescribedRestTargetSeconds(snapshot: snapshot) == nil)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "No rest prescription on Incline Press."
        )
    }

    @Test func cardioNextDoesNotInventARestChange() {
        let benchId = UUID()
        let zone2Id = UUID()
        let live = session(
            name: "Hybrid",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 120, nil, []),
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
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextIsCardio)
        #expect(snapshot.nextPrescribedRestSeconds == nil)
        #expect(snapshot.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
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
        let finishedSnapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: finishedSnapshot, now: now)
                == MalachiteAskFitLog.noInProgressDialog
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(snapshot: finishedSnapshot)
                == MalachiteAskFitLog.noInProgressDialog
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: finishedSnapshot)
                == MalachiteAskFitLog.noInProgressDialog
        )

        let missing = MalachiteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: missing)
                == MalachiteAskFitLog.noInProgressDialog
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
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.completedSetCount == 0)
        #expect(snapshot.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
    }

    @Test func zeroSecondCardioDoesNotCountAsASet() {
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
                            cardioMetrics: CardioMetrics(durationSec: 0)
                        )
                    ]
                )
            ]
        )
        let snapshot = MalachiteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.completedSetCount == 0)
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: snapshot)
                == "No sets done this workout."
        )
    }

    @Test func readyToFinishSpeaksLastPrescribedAndSetCount() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
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
        let now = Date()
        let snapshot = MalachiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.completedSetCount == 3)
        #expect(snapshot.canUseNextPrescribedRest == false)
        #expect(
            MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(snapshot: snapshot)
                == "3 sets done this workout."
        )
        #expect(
            MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(snapshot: snapshot)
                == "Last prescribed rest this workout was 1 minute, 30 seconds on Bench Press."
        )
        #expect(
            MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot, now: now)
                == "No next exercise. Push A is ready to finish."
        )
    }

    @Test func malachiteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.MalachiteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsIncomplete: true,
            nextExerciseName: "Incline Press",
            nextIsCardio: false,
            nextPrescribedRestSeconds: 150,
            lastCompletedExerciseName: "Flyes",
            lastCompletedPrescribedRestSeconds: 75,
            completedSetCount: 4,
            canUseNextPrescribedRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishMalachiteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadMalachiteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishMalachiteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadMalachiteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(MalachiteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishMalachiteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadMalachiteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseNextPrescribedRestTime()
        #expect(FitLogIntentBridge.consumePendingUseNextPrescribedRestTime())
        #expect(FitLogIntentBridge.consumePendingUseNextPrescribedRestTime() == false)
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
