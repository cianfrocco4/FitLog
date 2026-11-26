//
//  MorganiteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct MorganiteAskFitLogTests {

    @Test func nextLastWorkingRestIgnoresFocusedAndSkipsWarmupOnNext() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
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
                    120,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 10,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 150,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.lastWorkingRestSeconds == 150)
        #expect(snapshot.lastWorkingRestExerciseName == "Incline Press")
        #expect(snapshot.workingSetsLogged == 2)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(MorganiteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 150)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 30 seconds."
        )
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest next exercise was 2 minutes, 30 seconds on Incline Press."
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Incline Press."
        )
    }

    @Test func nextWarmupOnlyDoesNotBorrowLastWorkingRestFromFocusedOrTwoAhead() {
        let benchId = UUID()
        let inclineId = UUID()
        let flyId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
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
                    120,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 10,
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .warmup
                        )
                    ]
                ),
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
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == MorganiteAskFitLog.noWorkingRestDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noWorkingRestDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noWorkingSetsDialog
        )
    }

    @Test func laterWorkingRestOnNextRowBeatsEarlierOnSameRow() {
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
                    4,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 45,
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
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 90)
        #expect(snapshot.workingSetsLogged == 2)
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest next exercise was 1 minute, 30 seconds on Incline Press."
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Incline Press."
        )
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func nextCardioDoesNotInventWorkingRestOrWorkingSets() {
        let benchId = UUID()
        let zone2Id = UUID()
        let live = session(
            name: "Mixed",
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
                            weight: 185,
                            reps: 8,
                            restTime: 120,
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
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == MorganiteAskFitLog.noWorkingRestDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noWorkingSetsDialog
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
            completedExerciseIds: [],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    90,
                    nil,
                    []
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
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let idle = MorganiteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: idle, now: now)
                == MorganiteAskFitLog.noRestTimerDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: idle)
                == "Last working rest next exercise was 1 minute, 30 seconds on Incline Press."
        )

        let expired = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: expired, now: now)
                == MorganiteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseNextLastWorkingRestWithoutStartingRest() {
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
                    []
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 210,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastWorkingRest)
        #expect(MorganiteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 210)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
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
                    []
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 900,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 900)
        #expect(MorganiteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
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
                    []
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
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 60)
        #expect(snapshot.workingSetsLogged == 2)
        #expect(MorganiteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 60)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Incline Press."
        )
    }

    @Test func finishedAndMissingSessionsStayQuiet() {
        let benchId = UUID()
        let inclineId = UUID()
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 600,
            activeExerciseIds: [benchId],
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
        let finishedSnapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: finishedSnapshot, now: now)
                == MorganiteAskFitLog.noInProgressDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: finishedSnapshot)
                == MorganiteAskFitLog.noInProgressDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: finishedSnapshot)
                == MorganiteAskFitLog.noInProgressDialog
        )

        let missing = MorganiteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: missing)
                == MorganiteAskFitLog.noInProgressDialog
        )
    }

    @Test func noExerciseInFocusStaysQuietEvenWhenLaterRowsHaveWorkingRest() {
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
                    []
                ),
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == MorganiteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noExerciseInFocusDialog
        )
    }

    @Test func lastFocusedExerciseHasNoNext() {
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            exercises: [
                (
                    "Incline Press",
                    inclineId,
                    4,
                    "10",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == MorganiteAskFitLog.noNextExerciseDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noNextExerciseDialog
        )
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == MorganiteAskFitLog.noNextExerciseDialog
        )
    }

    @Test func openSlotAsNextDoesNotSkipToTwoAhead() {
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
                    loggedSets: []
                ),
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
                )
            ],
            activeExerciseIds: [benchId]
        )
        let now = Date()
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextIsPlaceholder)
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
    }

    @Test func nextWorkingRestStillAppliesWhenNextIsIncomplete() {
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
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .working
                        ),
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
        let snapshot = MorganiteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(snapshot.workingSetsLogged == 3)
        #expect(
            MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "3 working sets logged on Incline Press."
        )
        #expect(
            MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
    }

    @Test func morganiteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.MorganiteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsIncomplete: true,
            focusedIsPlaceholder: false,
            nextExerciseName: "Incline Press",
            nextIsIncomplete: false,
            nextIsPlaceholder: false,
            lastWorkingRestSeconds: 150,
            lastWorkingRestExerciseName: "Incline Press",
            workingSetsLogged: 2,
            canUseLastWorkingRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishMorganiteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadMorganiteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishMorganiteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadMorganiteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(MorganiteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishMorganiteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadMorganiteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseNextExerciseLastWorkingRestTime()
        #expect(FitLogIntentBridge.consumePendingUseNextExerciseLastWorkingRestTime())
        #expect(FitLogIntentBridge.consumePendingUseNextExerciseLastWorkingRestTime() == false)
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
