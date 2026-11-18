//
//  LarimarAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct LarimarAskFitLogTests {

    @Test func nextLastRestAndPreviousPrescribedRestUseNeighborRows() {
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
                    "8-12",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 80,
                            timestamp: Date().addingTimeInterval(-120),
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
                            timestamp: Date().addingTimeInterval(-40),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 155,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-10),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextIsCardio == false)
        #expect(snapshot.nextLastRestSeconds == 75)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousPrescribedRestSeconds == 120)
        #expect(snapshot.sessionLastRestSeconds == 75)
        #expect(snapshot.sessionLastRestExerciseName == "Incline Press")
        #expect(snapshot.canUseNextLastRest)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 2 minutes on Incline Press."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 1 minute, 15 seconds on Incline Press."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 1 minute, 15 seconds."
        )
        #expect(LarimarAskFitLog.nextLastRestTargetSeconds(snapshot: snapshot) == 75)
    }

    @Test func wrapToFirstIncompleteAndSkipZeroSecondRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 400,
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
                            restTime: 0,
                            timestamp: Date(),
                            setType: .warmup
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
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = LarimarAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.focusedExerciseName == "Incline Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextLastRestSeconds == 90)
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousPrescribedRestSeconds == 90)
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 1 minute, 30 seconds on Bench Press."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot)
                == LarimarAskFitLog.noRestTimerDialog
        )
        #expect(LarimarAskFitLog.canUseNextLastRest(snapshot: snapshot) == false)
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
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(45),
            now: now
        )
        #expect(snapshot.focusedExerciseName == "Bench Press")
        #expect(snapshot.focusedIsIncomplete)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUseNextLastRest == false)
        #expect(snapshot.sessionLastRestSeconds == nil)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Already on Bench Press."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "Already on Bench Press."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "No rest logged yet this workout."
        )
    }

    @Test func nextCardioHasNoLastRestAndPreviousCardioHasNoPrescription() {
        let zone2Id = UUID()
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
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
                ),
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
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(50),
            now: now
        )
        #expect(snapshot.nextIsCardio)
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextLastRestSeconds == nil)
        #expect(snapshot.previousExerciseName == "Zone 2")
        #expect(snapshot.previousIsCardio)
        #expect(snapshot.previousPrescribedRestSeconds == nil)
        #expect(snapshot.sessionLastRestSeconds == 90)
        #expect(snapshot.sessionLastRestExerciseName == "Bench Press")
        #expect(snapshot.canUseNextLastRest == false)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Zone 2 is cardio."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "No rest logged yet on Zone 2."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 1 minute, 30 seconds on Bench Press."
        )
    }

    @Test func sessionRestOverrideWinsOverLibraryDefaultOnPrevious() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            sessionRestOverrideByExerciseId: [benchId: 45],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = LarimarAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousPrescribedRestSeconds == 45)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 45 seconds on Bench Press."
        )
    }

    @Test func warmupLastRestCountsOnNextRow() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 90, nil, []),
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
                            reps: 8,
                            restTime: 40,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let snapshot = LarimarAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.nextLastRestSeconds == 40)
        #expect(snapshot.previousPrescribedRestSeconds == 150)
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 40 seconds on Incline Press."
        )
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 2 minutes, 30 seconds on Incline Press."
        )
    }

    @Test func remainingOneSecondCanUseNextLastRestWithoutStartingRest() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
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
                            weight: 155,
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
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(1),
            now: now
        )
        #expect(snapshot.canUseNextLastRest)
        #expect(LarimarAskFitLog.nextLastRestTargetSeconds(snapshot: snapshot) == 90)
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
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
                            weight: 155,
                            reps: 10,
                            restTime: 720,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(LarimarAskFitLog.nextLastRestTargetSeconds(snapshot: snapshot) == 600)
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 10 minutes."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 12 minutes on Incline Press."
        )
    }

    @Test func expiredRestDoesNotInventAStart() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
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
                            weight: 155,
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
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(-5),
            now: now
        )
        #expect(snapshot.canUseNextLastRest == false)
        #expect(snapshot.restEndsAtEpoch == nil)
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == LarimarAskFitLog.noRestTimerDialog
        )
    }

    @Test func nothingFocusedFallsThroughToFirstIncompleteNextLastRest() {
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [],
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    3,
                    "8",
                    90,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 50,
                            timestamp: Date().addingTimeInterval(-80),
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
                            weight: 155,
                            reps: 10,
                            restTime: 75,
                            timestamp: Date().addingTimeInterval(-20),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(70),
            now: now
        )
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextLastRestSeconds == 50)
        #expect(snapshot.previousExerciseName == "Incline Press")
        #expect(snapshot.previousPrescribedRestSeconds == 120)
        #expect(snapshot.sessionLastRestSeconds == 75)
        #expect(snapshot.sessionLastRestExerciseName == "Incline Press")
        #expect(snapshot.canUseNextLastRest)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Rest 2 minutes on Incline Press."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "Rest now 50 seconds."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 1 minute, 15 seconds on Incline Press."
        )
    }

    @Test func sessionLastRestIncludesCompletedEarlierRow() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 1800,
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
                            restTime: 110,
                            timestamp: Date().addingTimeInterval(-5),
                            setType: .working
                        )
                    ]
                ),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let now = Date()
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUseNextLastRest == false)
        #expect(snapshot.sessionLastRestSeconds == 110)
        #expect(snapshot.sessionLastRestExerciseName == "Bench Press")
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 1 minute, 50 seconds on Bench Press."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "Already on Incline Press."
        )
    }

    @Test func restDayAndFinishedSessionStayQuiet() {
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: nil)
                == LarimarAskFitLog.noInProgressDialog
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: nil)
                == LarimarAskFitLog.noInProgressDialog
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: nil)
                == LarimarAskFitLog.noInProgressDialog
        )
        #expect(LarimarAskFitLog.canUseNextLastRest(snapshot: nil) == false)

        let empty = LarimarAskFitLog.querySnapshot(
            inProgress: nil,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(empty.inProgressWorkoutName == nil)
        #expect(empty.canUseNextLastRest == false)
        #expect(empty.restEndsAtEpoch != nil)
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: empty)
                == LarimarAskFitLog.noInProgressDialog
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: empty)
                == LarimarAskFitLog.noInProgressDialog
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
        let finishedSnapshot = LarimarAskFitLog.querySnapshot(
            inProgress: finished,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(finishedSnapshot.inProgressWorkoutName == nil)
        #expect(finishedSnapshot.canUseNextLastRest == false)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: finishedSnapshot)
                == LarimarAskFitLog.noInProgressDialog
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: finishedSnapshot)
                == LarimarAskFitLog.noInProgressDialog
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: finishedSnapshot)
                == LarimarAskFitLog.noInProgressDialog
        )
    }

    @Test func readyToFinishStillSpeaksSessionLastRest() {
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
                            timestamp: Date().addingTimeInterval(1),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let now = Date()
        let snapshot = LarimarAskFitLog.querySnapshot(
            inProgress: live,
            restEndsAt: now.addingTimeInterval(40),
            now: now
        )
        #expect(snapshot.isReadyToFinish)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.canUseNextLastRest == false)
        #expect(snapshot.sessionLastRestSeconds == 75)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "No previous exercise. Push A is ready to finish."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot, now: now)
                == "No next exercise. Push A is ready to finish."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "Last rest this workout was 1 minute, 15 seconds on Bench Press."
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
        let snapshot = LarimarAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.hasOpenPlaceholder)
        #expect(snapshot.focusedExerciseName == nil)
        #expect(snapshot.previousExerciseName == nil)
        #expect(snapshot.nextExerciseName == nil)
        #expect(snapshot.sessionLastRestSeconds == nil)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "Push A still has an open slot."
        )
        #expect(
            LarimarAskFitLog.thisWorkoutLastRestDialog(snapshot: snapshot)
                == "No rest logged yet this workout."
        )
        #expect(
            LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot)
                == LarimarAskFitLog.noRestTimerDialog
        )
    }

    @Test func noPrescriptionWhenLibraryDefaultIsZero() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 200,
            activeExerciseIds: [inclineId],
            exercises: [
                ("Bench Press", benchId, 3, "8", 0, nil, []),
                ("Incline Press", inclineId, 4, "10", 120, nil, [])
            ]
        )
        let snapshot = LarimarAskFitLog.querySnapshot(inProgress: live, restEndsAt: nil)
        #expect(snapshot.previousExerciseName == "Bench Press")
        #expect(snapshot.previousPrescribedRestSeconds == nil)
        #expect(
            LarimarAskFitLog.previousExercisePrescribedRestDialog(snapshot: snapshot)
                == "No rest prescription on Bench Press."
        )
    }

    @Test func larimarSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.LarimarSessionSnapshot(
            inProgressWorkoutName: "Push A",
            focusedExerciseName: "Bench Press",
            focusedIsCardio: false,
            focusedIsIncomplete: true,
            previousExerciseName: "Flyes",
            previousIsCardio: false,
            previousPrescribedRestSeconds: 90,
            nextExerciseName: "Incline Press",
            nextIsCardio: false,
            nextLastRestSeconds: 75,
            sessionLastRestSeconds: 80,
            sessionLastRestExerciseName: "Flyes",
            canUseNextLastRest: true,
            restEndsAtEpoch: 1_700_000_090,
            hasOpenPlaceholder: false,
            isReadyToFinish: false
        )
        FitLogIntentBridge.publishLarimarSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadLarimarSessionSnapshot()
        #expect(loaded == original)

        let restEnds = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 45)
        FitLogIntentBridge.publishLarimarRestEndsAt(restEnds)
        let loadedRest = FitLogIntentBridge.loadLarimarRestEndsAt()
        #expect(loadedRest != nil)
        #expect(LarimarAskFitLog.remainingRestSeconds(restEndsAt: loadedRest) != nil)

        FitLogIntentBridge.publishLarimarRestEndsAt(Date().addingTimeInterval(-5))
        #expect(FitLogIntentBridge.loadLarimarRestEndsAt() == nil)

        FitLogIntentBridge.queueUseNextLastRestTime()
        #expect(FitLogIntentBridge.consumePendingUseNextLastRestTime())
        #expect(FitLogIntentBridge.consumePendingUseNextLastRestTime() == false)
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
