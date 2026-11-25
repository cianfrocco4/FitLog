//
//  BerylAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct BerylAskFitLogTests {

    @Test func previousLastWorkingRestIgnoresFocusedAndSkipsWarmupOnPrevious() {
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
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.lastWorkingRestSeconds == 150)
        #expect(snapshot.lastWorkingRestExerciseName == "Bench Press")
        #expect(snapshot.workingSetsLogged == 2)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(BerylAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 150)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 30 seconds."
        )
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest previous exercise was 2 minutes, 30 seconds on Bench Press."
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Bench Press."
        )
    }

    @Test func previousWarmupOnlyDoesNotBorrowLastWorkingRestFromFocusedOrTwoBack() {
        let flyId = UUID()
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [flyId, benchId],
            exercises: [
                (
                    "Chest Fly",
                    flyId,
                    3,
                    "12",
                    60,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 40,
                            reps: 12,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-120),
                            setType: .working
                        )
                    ]
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
                            weight: 95,
                            reps: 8,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .warmup
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == BerylAskFitLog.noWorkingRestDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: snapshot)
                == BerylAskFitLog.noWorkingRestDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == BerylAskFitLog.noWorkingSetsDialog
        )
    }

    @Test func laterWorkingRestOnPreviousRowBeatsEarlierOnSameRow() {
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
                    4,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-30),
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
                            restTime: 45,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 90)
        #expect(snapshot.workingSetsLogged == 2)
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest previous exercise was 1 minute, 30 seconds on Bench Press."
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Bench Press."
        )
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func previousCardioDoesNotInventWorkingRestOrWorkingSets() {
        let zone2Id = UUID()
        let benchId = UUID()
        let live = session(
            name: "Mixed",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
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
                            timestamp: Date().addingTimeInterval(-20),
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == BerylAskFitLog.noWorkingRestDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == BerylAskFitLog.noWorkingSetsDialog
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
        let idle = BerylAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: idle, now: now)
                == BerylAskFitLog.noRestTimerDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: idle)
                == "Last working rest previous exercise was 1 minute, 30 seconds on Bench Press."
        )

        let expired = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: expired, now: now)
                == BerylAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUsePreviousLastWorkingRestWithoutStartingRest() {
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastWorkingRest)
        #expect(BerylAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 210)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 900)
        #expect(BerylAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseLastWorkingRest)
    }

    @Test func zeroWorkingRestSkipsThatSetForRestButStillCountsTheSet() {
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
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-20),
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 60)
        #expect(snapshot.workingSetsLogged == 2)
        #expect(BerylAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 60)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Bench Press."
        )
    }

    @Test func finishedAndMissingSessionsStayQuiet() {
        let benchId = UUID()
        let inclineId = UUID()
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 600,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [benchId, inclineId],
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
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        )
                    ]
                ),
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
                            weight: 135,
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
        let finishedSnapshot = BerylAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: finishedSnapshot, now: now)
                == BerylAskFitLog.noInProgressDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: finishedSnapshot)
                == BerylAskFitLog.noInProgressDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: finishedSnapshot)
                == BerylAskFitLog.noInProgressDialog
        )

        let missing = BerylAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: missing)
                == BerylAskFitLog.noInProgressDialog
        )
    }

    @Test func noExerciseInFocusStaysQuietEvenWhenEarlierRowsHaveWorkingRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [],
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == BerylAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: snapshot)
                == BerylAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == BerylAskFitLog.noExerciseInFocusDialog
        )
    }

    @Test func firstFocusedExerciseHasNoPrevious() {
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == BerylAskFitLog.noPreviousExerciseDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: snapshot)
                == BerylAskFitLog.noPreviousExerciseDialog
        )
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == BerylAskFitLog.noPreviousExerciseDialog
        )
    }

    @Test func openSlotAsPreviousDoesNotSkipToTwoBack() {
        let flyId = UUID()
        let inclineId = UUID()
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
        let fly = workoutExercise("Chest Fly", flyId, 3, "12", 60, nil)
        let incline = workoutExercise("Incline Press", inclineId, 4, "10", 90, nil)
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [fly, openSlot, incline]),
            startTime: Date().addingTimeInterval(-200),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: fly,
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 40,
                            reps: 12,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-40),
                            setType: .working
                        )
                    ]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: openSlot,
                    loggedSets: []
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.previousIsPlaceholder)
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            BerylAskFitLog.previousExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
    }

    @Test func previousWorkingRestStillAppliesWhenFocusedIsIncomplete() {
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
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-10),
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
        let snapshot = BerylAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(snapshot.workingSetsLogged == 3)
        #expect(
            BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "3 working sets logged on Bench Press."
        )
        #expect(
            BerylAskFitLog.usePreviousExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
    }

    @Test func berylSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.BerylSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsIncomplete: true,
            focusedIsPlaceholder: false,
            previousExerciseName: "Bench Press",
            previousIsIncomplete: false,
            previousIsPlaceholder: false,
            lastWorkingRestSeconds: 150,
            lastWorkingRestExerciseName: "Bench Press",
            workingSetsLogged: 2,
            canUseLastWorkingRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishBerylSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadBerylSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishBerylRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadBerylRestEndsAt()
        #expect(loadedRest != nil)
        #expect(BerylAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishBerylRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadBerylRestEndsAt() == nil)

        FitLogIntentBridge.queueUsePreviousExerciseLastWorkingRestTime()
        #expect(FitLogIntentBridge.consumePendingUsePreviousExerciseLastWorkingRestTime())
        #expect(FitLogIntentBridge.consumePendingUsePreviousExerciseLastWorkingRestTime() == false)
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
