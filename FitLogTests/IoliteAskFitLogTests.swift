//
//  IoliteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct IoliteAskFitLogTests {

    @Test func lastWorkingRestSkipsWarmupAndUsesWorkingSetNotPrescribed() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
            activeExerciseIds: [inclineId],
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
                            weight: 135,
                            reps: 8,
                            restTime: 45,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 150,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 180,
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
                            reps: 10,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(10),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastCompletedStrengthExerciseName == "Bench Press")
        #expect(snapshot.lastWorkingRestSeconds == 180)
        #expect(snapshot.lastWorkingRestExerciseName == "Bench Press")
        #expect(snapshot.canUseLastWorkingRest)
        #expect(IoliteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 180)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 3 minutes."
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest this workout was 3 minutes on Bench Press."
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: snapshot)
                == "Last finished strength exercise this workout was Bench Press."
        )
    }

    @Test func laterWorkingRestOnFocusedRowBeatsEarlierCompleted() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
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
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
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
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
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
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedStrengthExerciseName == "Bench Press")
        #expect(snapshot.lastWorkingRestSeconds == 75)
        #expect(snapshot.lastWorkingRestExerciseName == "Incline Press")
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest this workout was 1 minute, 15 seconds on Incline Press."
        )
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
    }

    @Test func lastCompletedStrengthSkipsCardioAndLastWorkingRestSkipsCardioRest() {
        let zone2Id = UUID()
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Hybrid",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [benchId, zone2Id],
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
                            restTime: 120,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 120,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 120,
                            timestamp: Date().addingTimeInterval(-30),
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
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 60,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    75,
                    nil,
                    []
                )
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedStrengthExerciseName == "Bench Press")
        #expect(snapshot.lastWorkingRestSeconds == 120)
        #expect(snapshot.lastWorkingRestExerciseName == "Bench Press")
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: snapshot)
                == "Last finished strength exercise this workout was Bench Press."
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest this workout was 2 minutes on Bench Press."
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
                ("Incline Press", inclineId, 4, "10", 150, nil, [])
            ]
        )
        let now = Date()
        let idle = IoliteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastWorkingRest == false)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: idle, now: now)
                == IoliteAskFitLog.noRestTimerDialog
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: idle)
                == "Last working rest this workout was 1 minute, 30 seconds on Bench Press."
        )

        let expired = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastWorkingRest == false)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: expired, now: now)
                == IoliteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseLastWorkingRestWithoutStartingRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
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
                            restTime: 210,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 210,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 210,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastWorkingRest)
        #expect(IoliteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 210)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 3 minutes, 30 seconds."
        )
    }

    @Test func workingRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
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
                            restTime: 900,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 900,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 900,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 900)
        #expect(IoliteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseLastWorkingRest)
    }

    @Test func zeroWorkingRestSkipsThatSet() {
        let flyesId = UUID()
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [flyesId, benchId],
            exercises: [
                (
                    "Flyes",
                    flyesId,
                    3,
                    "12",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 25,
                            reps: 12,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 25,
                            reps: 12,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 25,
                            reps: 12,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .working
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
                            weight: 185,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .working
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
                ),
                ("Incline Press", inclineId, 4, "10", 150, nil, [])
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedStrengthExerciseName == "Bench Press")
        #expect(snapshot.lastWorkingRestSeconds == 60)
        #expect(snapshot.lastWorkingRestExerciseName == "Flyes")
        #expect(IoliteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 60)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
    }

    @Test func cardioOnlyLastFinishedDoesNotInventARestChange() {
        let zone2Id = UUID()
        let live = session(
            name: "Zone 2",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [zone2Id],
            completedExerciseIds: [zone2Id],
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
                            restTime: 90,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedStrengthExerciseName == nil)
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == IoliteAskFitLog.noWorkingRestDialog
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: snapshot)
                == "No finished strength exercise this workout."
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: snapshot)
                == IoliteAskFitLog.noWorkingRestDialog
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
        let finishedSnapshot = IoliteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastWorkingRest == false)
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: finishedSnapshot, now: now)
                == IoliteAskFitLog.noInProgressDialog
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: finishedSnapshot)
                == IoliteAskFitLog.noInProgressDialog
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: finishedSnapshot)
                == IoliteAskFitLog.noInProgressDialog
        )

        let missing = IoliteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: missing)
                == IoliteAskFitLog.noInProgressDialog
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
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.lastCompletedStrengthExerciseName == nil)
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
    }

    @Test func warmupOnlyDoesNotInventWorkingRest() {
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
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.lastCompletedStrengthExerciseName == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(snapshot: snapshot)
                == IoliteAskFitLog.noWorkingRestDialog
        )
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == IoliteAskFitLog.noWorkingRestDialog
        )
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: snapshot)
                == "No finished strength exercise this workout."
        )
    }

    @Test func readyToFinishSpeaksLastWorkingRestAndLastStrength() {
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
        let snapshot = IoliteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(
            IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(snapshot: snapshot)
                == "Last finished strength exercise this workout was Bench Press."
        )
        #expect(
            IoliteAskFitLog.useThisWorkoutLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func ioliteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.IoliteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsIncomplete: true,
            lastCompletedStrengthExerciseName: "Bench Press",
            lastWorkingRestSeconds: 180,
            lastWorkingRestExerciseName: "Bench Press",
            canUseLastWorkingRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishIoliteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadIoliteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishIoliteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadIoliteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(IoliteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishIoliteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadIoliteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseThisWorkoutLastWorkingRestTime()
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastWorkingRestTime())
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastWorkingRestTime() == false)
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
