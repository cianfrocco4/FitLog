//
//  AzuriteAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct AzuriteAskFitLogTests {

    @Test func lastPrescribedUsesFinishedStrengthNotLoggedRestOrFocusedLeftover() {
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.lastCompletedExerciseName == "Bench Press")
        #expect(snapshot.lastCompletedIsCardio == false)
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 90)
        #expect(snapshot.canUseLastPrescribedRest)
        #expect(AzuriteAskFitLog.lastPrescribedRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "Last finished exercise this workout was Bench Press."
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(snapshot: snapshot)
                == "No cardio duration this workout."
        )
    }

    @Test func sessionOverrideWinsOverLibraryDefaultOnLastCompleted() {
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(30),
            now: now
        )
        #expect(snapshot.lastCompletedExerciseName == "Bench Press")
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 45)
        #expect(AzuriteAskFitLog.lastPrescribedRestTargetSeconds(snapshot: snapshot) == 45)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 45 seconds."
        )
    }

    @Test func lastPrescribedSkipsCardioCompletedAndLastCardioSpeaksDuration() {
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedExerciseName == "Bench Press")
        #expect(snapshot.lastCompletedIsCardio == false)
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 150)
        #expect(snapshot.lastCardioExerciseName == "Zone 2")
        #expect(snapshot.lastCardioDurationSeconds == 45 * 60)
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(snapshot: snapshot)
                == "Last cardio this workout was 45 minutes on Zone 2."
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "Last finished exercise this workout was Bench Press."
        )
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 2 minutes, 30 seconds."
        )
    }

    @Test func lastCompletedExercisePrefersLaterCardioRow() {
        let benchId = UUID()
        let zone2Id = UUID()
        let live = session(
            name: "Hybrid",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [zone2Id],
            completedExerciseIds: [benchId, zone2Id],
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
                (
                    "Zone 2",
                    zone2Id,
                    1,
                    "—",
                    90,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 20 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 20 * 60)
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedExerciseName == "Zone 2")
        #expect(snapshot.lastCompletedIsCardio)
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 90)
        #expect(snapshot.lastCardioDurationSeconds == 20 * 60)
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "Last finished exercise this workout was Zone 2."
        )
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
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
        let idle = AzuriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil, now: now)
        #expect(idle.canUseLastPrescribedRest == false)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: idle, now: now)
                == AzuriteAskFitLog.noRestTimerDialog
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: idle)
                == "Last finished exercise this workout was Bench Press."
        )

        let expired = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(expired.canUseLastPrescribedRest == false)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: expired, now: now)
                == AzuriteAskFitLog.noRestTimerDialog
        )
    }

    @Test func remainingOneSecondCanUseLastPrescribedWithoutStartingRest() {
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
                    120,
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
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseLastPrescribedRest)
        #expect(AzuriteAskFitLog.lastPrescribedRestTargetSeconds(snapshot: snapshot) == 120)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
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
            activeExerciseIds: [inclineId],
            completedExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    900,
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
                ("Incline Press", inclineId, 4, "10", 90, nil, [])
            ]
        )
        let now = Date()
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 900)
        #expect(AzuriteAskFitLog.lastPrescribedRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(snapshot.canUseLastPrescribedRest)
    }

    @Test func zeroPrescribedRestSkipsThatRow() {
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
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 25,
                            reps: 12,
                            restTime: 60,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 25,
                            reps: 12,
                            restTime: 60,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Bench Press",
                    benchId,
                    3,
                    "8",
                    0,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .working
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 0,
                            timestamp: Date(),
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedExerciseName == "Bench Press")
        #expect(snapshot.lastCompletedPrescribedRestSeconds == 90)
        #expect(AzuriteAskFitLog.lastPrescribedRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
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
                            restTime: 0,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedExerciseName == "Zone 2")
        #expect(snapshot.lastCompletedIsCardio)
        #expect(snapshot.lastCompletedPrescribedRestSeconds == nil)
        #expect(snapshot.canUseLastPrescribedRest == false)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Last finished exercise is cardio."
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(snapshot: snapshot)
                == "Last cardio this workout was 45 minutes on Zone 2."
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
        let finishedSnapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseLastPrescribedRest == false)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: finishedSnapshot, now: now)
                == AzuriteAskFitLog.noInProgressDialog
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(snapshot: finishedSnapshot)
                == AzuriteAskFitLog.noInProgressDialog
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: finishedSnapshot)
                == AzuriteAskFitLog.noInProgressDialog
        )

        let missing = AzuriteAskFitLog.querySnapshot(inProgress: nil, restEndsAt: nil)
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: missing)
                == AzuriteAskFitLog.noInProgressDialog
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.lastCompletedExerciseName == nil)
        #expect(snapshot.lastCardioDurationSeconds == nil)
        #expect(snapshot.canUseLastPrescribedRest == false)
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Push A still has an open slot."
        )
    }

    @Test func zeroSecondCardioDoesNotInventADuration() {
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
        let snapshot = AzuriteAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.lastCardioDurationSeconds == nil)
        #expect(snapshot.lastCompletedExerciseName == nil)
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(snapshot: snapshot)
                == "No cardio duration this workout."
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "No finished exercise this workout."
        )
    }

    @Test func readyToFinishSpeaksLastPrescribedAndLastExercise() {
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.canUseLastPrescribedRest)
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "Last finished exercise this workout was Bench Press."
        )
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 30 seconds."
        )
    }

    @Test func noFinishedExerciseAndLiveRestStaysQuiet() {
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
        let snapshot = AzuriteAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.lastCompletedExerciseName == nil)
        #expect(snapshot.canUseLastPrescribedRest == false)
        #expect(
            AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot, now: now)
                == AzuriteAskFitLog.noRestPrescriptionDialog
        )
        #expect(
            AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(snapshot: snapshot)
                == "No finished exercise this workout."
        )
    }

    @Test func azuriteSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.AzuriteSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Incline Press",
            focusedIsIncomplete: true,
            lastCompletedExerciseName: "Bench Press",
            lastCompletedIsCardio: false,
            lastCompletedPrescribedRestSeconds: 90,
            lastCardioExerciseName: "Zone 2",
            lastCardioDurationSeconds: 2700,
            canUseLastPrescribedRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishAzuriteSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadAzuriteSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishAzuriteRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadAzuriteRestEndsAt()
        #expect(loadedRest != nil)
        #expect(AzuriteAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishAzuriteRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadAzuriteRestEndsAt() == nil)

        FitLogIntentBridge.queueUseThisWorkoutLastPrescribedRestTime()
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastPrescribedRestTime())
        #expect(FitLogIntentBridge.consumePendingUseThisWorkoutLastPrescribedRestTime() == false)
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
