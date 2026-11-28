//
//  HiddeniteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct HiddeniteAskFitLogTests {

    @Test func focusedLastWarmupRestIgnoresOtherExercisesAndSkipsWorking() {
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
                            weight: 95,
                            reps: 8,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-60),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 180,
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
                            restTime: 40,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .warmup
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWarmupRestSeconds == 40)
        #expect(snapshot.lastWarmupRestExerciseName == "Incline Press")
        #expect(snapshot.warmupSetsLogged == 1)
        #expect(snapshot.canUseLastWarmupRest)
        #expect(HiddeniteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 40)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 40 seconds."
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == "Last warmup rest this exercise was 40 seconds on Incline Press."
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == "1 warmup set logged on Incline Press."
        )
    }

    @Test func laterWarmupOnAnotherRowDoesNotReplaceFocusedWarmupRest() {
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.lastWarmupRestSeconds == 40)
        #expect(snapshot.lastWarmupRestExerciseName == "Bench Press")
        #expect(snapshot.warmupSetsLogged == 1)
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == "Last warmup rest this exercise was 40 seconds on Bench Press."
        )
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 40 seconds."
        )
    }

    @Test func focusedWorkingOnlyDoesNotBorrowLastWarmupRestFromAnotherExercise() {
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
                            weight: 95,
                            reps: 8,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-90),
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWarmupRestSeconds == nil)
        #expect(snapshot.warmupSetsLogged == 0)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == HiddeniteAskFitLog.noWarmupRestDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noWarmupRestDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noWarmupSetsDialog
        )
    }

    @Test func laterWarmupRestOnFocusedRowBeatsEarlierOnSameRow() {
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
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 10,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 115,
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == 90)
        #expect(snapshot.warmupSetsLogged == 2)
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == "Last warmup rest this exercise was 1 minute, 30 seconds on Incline Press."
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == "2 warmup sets logged on Incline Press."
        )
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func focusedCardioDoesNotInventWarmupRestOrWarmupSets() {
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
                            setType: .warmup,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Zone 2")
        #expect(snapshot.lastWarmupRestSeconds == nil)
        #expect(snapshot.warmupSetsLogged == 0)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == HiddeniteAskFitLog.noWarmupRestDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noWarmupSetsDialog
        )
    }

    @Test func idleAndExpiredRestDoNotInventAStart() {
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
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
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
        let idle = HiddeniteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: idle, now: now)
                == HiddeniteAskFitLog.noRestTimerDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: idle)
                == "Last warmup rest this exercise was 1 minute, 30 seconds on Incline Press."
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: idle)
                == "1 warmup set logged on Incline Press."
        )

        let expired = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: expired, now: now)
                == HiddeniteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseFocusedLastWarmupRestWithoutStartingRest() {
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
                            weight: 95,
                            reps: 10,
                            restTime: 210,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastWarmupRest)
        #expect(HiddeniteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 210)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 3 minutes, 30 seconds."
        )
    }

    @Test func warmupRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
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
                            weight: 95,
                            reps: 10,
                            restTime: 900,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == 900)
        #expect(HiddeniteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseLastWarmupRest)
    }

    @Test func zeroWarmupRestSkipsThatSetForRestButStillCountsTheSet() {
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
                    150,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 10,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 115,
                            reps: 10,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == 60)
        #expect(snapshot.warmupSetsLogged == 2)
        #expect(HiddeniteAskFitLog.lastWarmupRestTargetSeconds(snapshot: snapshot) == 60)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == "2 warmup sets logged on Incline Press."
        )
    }

    @Test func finishedAndMissingSessionsStayQuiet() {
        let inclineId = UUID()
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 600,
            activeExerciseIds: [inclineId],
            completedExerciseIds: [inclineId],
            exercises: [
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
        let finishedSnapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: finishedSnapshot, now: now)
                == HiddeniteAskFitLog.noInProgressDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: finishedSnapshot)
                == HiddeniteAskFitLog.noInProgressDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: finishedSnapshot)
                == HiddeniteAskFitLog.noInProgressDialog
        )

        let missing = HiddeniteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: missing)
                == HiddeniteAskFitLog.noInProgressDialog
        )
    }

    @Test func noExerciseInFocusStaysQuiet() {
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [],
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
                            weight: 95,
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == HiddeniteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noExerciseInFocusDialog
        )
    }

    @Test func openSlotElsewhereDoesNotMaskFocusedWarmupRest() {
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
        let incline = workoutExercise("Incline Press", inclineId, 4, "10", 90, nil)
        let live = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [incline, openSlot]),
            startTime: Date().addingTimeInterval(-200),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: incline,
                    loggedSets: [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: openSlot,
                    loggedSets: []
                )
            ],
            activeExerciseIds: [inclineId]
        )
        let now = Date()
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWarmupRestSeconds == 75)
        #expect(snapshot.canUseLastWarmupRest)
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == "Last warmup rest this exercise was 1 minute, 15 seconds on Incline Press."
        )
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedIsPlaceholder == false)
        #expect(snapshot.lastWarmupRestSeconds == nil)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == HiddeniteAskFitLog.noExerciseInFocusDialog
        )
    }

    @Test func workingOnlyDoesNotInventWarmupRest() {
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
                            restTime: 60,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWarmupRestSeconds == nil)
        #expect(snapshot.warmupSetsLogged == 0)
        #expect(snapshot.canUseLastWarmupRest == false)
        #expect(
            HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noWarmupRestDialog
        )
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == HiddeniteAskFitLog.noWarmupRestDialog
        )
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == HiddeniteAskFitLog.noWarmupSetsDialog
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
        let snapshot = HiddeniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish == false)
        #expect(snapshot.canUseLastWarmupRest)
        #expect(snapshot.warmupSetsLogged == 1)
        #expect(
            HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(snapshot: snapshot)
                == "1 warmup set logged on Bench Press."
        )
        #expect(
            HiddeniteAskFitLog.useThisExerciseLastWarmupRestDialog(snapshot: snapshot, now: now)
                == "Rest now 45 seconds."
        )
    }

    @Test func hiddeniteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.HiddeniteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsIncomplete: true,
            focusedIsPlaceholder: false,
            lastWarmupRestSeconds: 40,
            lastWarmupRestExerciseName: "Incline Press",
            warmupSetsLogged: 2,
            canUseLastWarmupRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishHiddeniteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadHiddeniteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishHiddeniteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadHiddeniteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(HiddeniteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishHiddeniteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadHiddeniteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseThisExerciseLastWarmupRestTime()
        #expect(FitLogIntentBridge.consumePendingUseThisExerciseLastWarmupRestTime())
        #expect(FitLogIntentBridge.consumePendingUseThisExerciseLastWarmupRestTime() == false)
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
