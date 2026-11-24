//
//  KyaniteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct KyaniteAskFitLogTests {

    @Test func focusedLastWorkingRestIgnoresOtherExercisesAndSkipsWarmup() {
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
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-30),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-15),
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWorkingRestSeconds == 75)
        #expect(snapshot.lastWorkingRestExerciseName == "Incline Press")
        #expect(snapshot.workingSetsLogged == 1)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(KyaniteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 75)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest this exercise was 1 minute, 15 seconds on Incline Press."
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "1 working set logged on Incline Press."
        )
    }

    @Test func focusedWarmupOnlyDoesNotBorrowLastWorkingRestFromAnotherExercise() {
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
                            weight: 185,
                            reps: 8,
                            restTime: 180,
                            timestamp: Date().addingTimeInterval(-90),
                            setType: .working
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
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == KyaniteAskFitLog.noWorkingRestDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noWorkingRestDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noWorkingSetsDialog
        )
    }

    @Test func laterWorkingRestOnFocusedRowBeatsEarlierOnSameRow() {
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 90)
        #expect(snapshot.workingSetsLogged == 2)
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest this exercise was 1 minute, 30 seconds on Incline Press."
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Incline Press."
        )
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func focusedCardioDoesNotInventWorkingRestOrWorkingSets() {
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Zone 2")
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == KyaniteAskFitLog.noWorkingRestDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noWorkingSetsDialog
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
        let idle = KyaniteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: idle, now: now)
                == KyaniteAskFitLog.noRestTimerDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: idle)
                == "Last working rest this exercise was 1 minute, 30 seconds on Incline Press."
        )

        let expired = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: expired, now: now)
                == KyaniteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseFocusedLastWorkingRestWithoutStartingRest() {
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
                            restTime: 210,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastWorkingRest)
        #expect(KyaniteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 210)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 3 minutes, 30 seconds."
        )
    }

    @Test func workingRestAboveCapStopsAtTenMinutesAndDoesNotSkip() {
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
                            restTime: 900,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 900)
        #expect(KyaniteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseLastWorkingRest)
    }

    @Test func zeroWorkingRestSkipsThatSetForRestButStillCountsTheSet() {
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == 60)
        #expect(snapshot.workingSetsLogged == 2)
        #expect(KyaniteAskFitLog.lastWorkingRestTargetSeconds(snapshot: snapshot) == 60)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute."
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "2 working sets logged on Incline Press."
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
        let finishedSnapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: finishedSnapshot, now: now)
                == KyaniteAskFitLog.noInProgressDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: finishedSnapshot)
                == KyaniteAskFitLog.noInProgressDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: finishedSnapshot)
                == KyaniteAskFitLog.noInProgressDialog
        )

        let missing = KyaniteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: missing)
                == KyaniteAskFitLog.noInProgressDialog
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == KyaniteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noExerciseInFocusDialog
        )
    }

    @Test func openSlotElsewhereDoesNotMaskFocusedWorkingRest() {
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
                            weight: 135,
                            reps: 10,
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
                )
            ],
            activeExerciseIds: [inclineId]
        )
        let now = Date()
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastWorkingRestSeconds == 75)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == "Last working rest this exercise was 1 minute, 15 seconds on Incline Press."
        )
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedIsPlaceholder == false)
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noExerciseInFocusDialog
        )
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == KyaniteAskFitLog.noExerciseInFocusDialog
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastWorkingRestSeconds == nil)
        #expect(snapshot.workingSetsLogged == 0)
        #expect(snapshot.canUseLastWorkingRest == false)
        #expect(
            KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noWorkingRestDialog
        )
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == KyaniteAskFitLog.noWorkingRestDialog
        )
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == KyaniteAskFitLog.noWorkingSetsDialog
        )
    }

    @Test func readyToFinishSpeaksFocusedLastWorkingRestAndWorkingSets() {
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
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-10),
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
        let snapshot = KyaniteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canUseLastWorkingRest)
        #expect(snapshot.workingSetsLogged == 3)
        #expect(
            KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(snapshot: snapshot)
                == "3 working sets logged on Bench Press."
        )
        #expect(
            KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func kyaniteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.KyaniteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsIncomplete: true,
            focusedIsPlaceholder: false,
            lastWorkingRestSeconds: 75,
            lastWorkingRestExerciseName: "Incline Press",
            workingSetsLogged: 1,
            canUseLastWorkingRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishKyaniteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadKyaniteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishKyaniteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadKyaniteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(KyaniteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishKyaniteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadKyaniteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseThisExerciseLastWorkingRestTime()
        #expect(FitLogIntentBridge.consumePendingUseThisExerciseLastWorkingRestTime())
        #expect(FitLogIntentBridge.consumePendingUseThisExerciseLastWorkingRestTime() == false)
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
