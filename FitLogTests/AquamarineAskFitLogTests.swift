//
//  AquamarineAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct AquamarineAskFitLogTests {

    @Test func lastWeightPrefersActiveUnfinishedStrengthAndSkipsHistoryWarmups() {
        let benchId = UUID()
        let inclineId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            activeExerciseIds: [benchId],
            exercises: [
                ("Bench Press", benchId, 3, nil, []),
                ("Incline Press", inclineId, 3, nil, [])
            ]
        )
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 60,
                            timestamp: Date().addingTimeInterval(-86_400),
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                ),
                (
                    "Incline Press",
                    inclineId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 70,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_300),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.lastWeightExerciseName == "Bench Press")
        #expect(snapshot.lastWeightCaption == "185 lb × 8 reps")
        #expect(snapshot.canApplyLastWeight)
        #expect(AquamarineAskFitLog.canApplyLastWeight(snapshot: snapshot))
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == "Logged Bench Press. Last 185 lb × 8 reps."
        )
        let applyable = AquamarineAskFitLog.applyableLastWeight(
            in: live,
            completedSessions: [history],
            displayUnit: .pounds
        )
        #expect(applyable?.exerciseName == "Bench Press")
        #expect(applyable?.exerciseIndex == 0)
        #expect(applyable?.weight == 185)
        #expect(applyable?.reps == 8)
        #expect(applyable?.restTime == 90)
    }

    @Test func alreadyLoggedActiveFallsThroughToNextUnfinishedStrength() {
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
                ("Incline Press", inclineId, 3, nil, [])
            ]
        )
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Incline Press",
                    inclineId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 70,
                            reps: 10,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_300),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.lastWeightExerciseName == "Incline Press")
        #expect(snapshot.lastWeightCaption == "70 lb × 10 reps")
        #expect(snapshot.canApplyLastWeight)
        let applyable = AquamarineAskFitLog.applyableLastWeight(
            in: live,
            completedSessions: [history],
            displayUnit: .pounds
        )
        #expect(applyable?.exerciseIndex == 1)
        #expect(applyable?.exerciseName == "Incline Press")
    }

    @Test func warmupsOnlyStillCountAsUnfinishedStrength() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 180,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
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
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.canApplyLastWeight)
        #expect(snapshot.lastWeightExerciseName == "Bench Press")
        #expect(snapshot.lastWeightCaption == "185 lb × 8 reps")
    }

    @Test func emptyInProgressDoesNotInventASetWithoutHistory() {
        let empty = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: empty,
            completedSessions: [],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.lastWeightExerciseName == "Bench Press")
        #expect(snapshot.lastWeightCaption == nil)
        #expect(snapshot.canApplyLastWeight == false)
        #expect(AquamarineAskFitLog.canApplyLastWeight(snapshot: snapshot) == false)
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noPreviousWeightDialog
        )
    }

    @Test func noInProgressDoesNotInventASetOrStart() {
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(AquamarineAskFitLog.canApplyLastWeight(snapshot: snapshot) == false)
        #expect(AquamarineAskFitLog.canApplyLastWeight(snapshot: nil) == false)
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noInProgressDialog
        )
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: nil)
                == AquamarineAskFitLog.noInProgressDialog
        )
        #expect(
            AquamarineAskFitLog.skipRestDialog(snapshot: nil)
                == AquamarineAskFitLog.noRestTimerDialog
        )
        #expect(
            AquamarineAskFitLog.restRemainingDialog(snapshot: nil)
                == AquamarineAskFitLog.noRestTimerDialog
        )
    }

    @Test func completedSessionIsNotTreatedAsInProgress() {
        let finished = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    3,
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
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: finished,
            completedSessions: [finished],
            displayUnit: .pounds,
            restEndsAt: Date().addingTimeInterval(90)
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(snapshot.canApplyLastWeight == false)
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noInProgressDialog
        )
        #expect(AquamarineAskFitLog.canSkipRest(snapshot: snapshot))
    }

    @Test func cardioOnlyDoesNotApplyLastWeight() {
        let zoneId = UUID()
        let live = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
            duration: 60,
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    []
                )
            ]
        )
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.inProgressWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.canApplyLastWeight == false)
        #expect(snapshot.lastWeightExerciseName == nil)
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noUnfinishedStrengthDialog
        )
        #expect(
            AquamarineAskFitLog.applyableLastWeight(
                in: live,
                completedSessions: [history],
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func alreadyLoggedWorkingSetsDoNotApplyLastWeight() {
        let benchId = UUID()
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
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.canApplyLastWeight == false)
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noUnfinishedStrengthDialog
        )
    }

    @Test func placeholdersAreSkippedForLastWeight() {
        let benchId = UUID()
        let placeholder = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: UUID(),
                    label: "Press",
                    targetedMuscles: [.other]
                )
            ),
            recommendedSets: 3
        )
        let bench = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: benchId,
                nameAtTimeOfLog: "Bench Press"
            )),
            recommendedSets: 3
        )
        let workout = Workout(id: UUID(), name: "Push A", exercises: [placeholder, bench])
        let live = WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date().addingTimeInterval(-120),
            endTime: nil,
            exerciseLogs: [
                ExerciseLog(id: UUID(), workoutExercise: placeholder, loggedSets: []),
                ExerciseLog(id: UUID(), workoutExercise: bench, loggedSets: [])
            ]
        )
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.lastWeightExerciseName == "Bench Press")
        #expect(snapshot.canApplyLastWeight)
        let applyable = AquamarineAskFitLog.applyableLastWeight(
            in: live,
            completedSessions: [history],
            displayUnit: .pounds
        )
        #expect(applyable?.exerciseIndex == 1)
    }

    @Test func blankWorkoutNameIsIgnored() {
        let blank = session(
            name: "  ",
            endedAt: nil,
            duration: 60,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: blank,
            completedSessions: [],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(AquamarineAskFitLog.canApplyLastWeight(snapshot: snapshot) == false)
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noInProgressDialog
        )
    }

    @Test func newerHistorySessionWinsForLastWeight() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [("Bench Press", benchId, 3, nil, [])]
        )
        let older = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-172_800),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 135,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-172_800),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let newer = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let applyable = AquamarineAskFitLog.applyableLastWeight(
            in: live,
            completedSessions: [older, newer],
            displayUnit: .pounds
        )
        #expect(applyable?.weight == 185)
        #expect(applyable?.caption == "185 lb × 8 reps")
    }

    @Test func kilogramsCaptionUsesDisplayUnit() {
        let benchId = UUID()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [("Bench Press", benchId, 3, nil, [])]
        )
        let history = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date().addingTimeInterval(-86_370),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .kilograms,
            restEndsAt: nil
        )
        #expect(snapshot.lastWeightCaption == "83.9 kg × 8 reps")
        #expect(
            AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
                == "Logged Bench Press. Last 83.9 kg × 8 reps."
        )
    }

    @Test func restRemainingUsesWallClockAndExpiresQuietly() {
        let now = Date()
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let running = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [],
            displayUnit: .pounds,
            restEndsAt: now.addingTimeInterval(90),
            now: now
        )
        #expect(running.restEndsAtEpoch != nil)
        #expect(AquamarineAskFitLog.canSkipRest(snapshot: running, now: now))
        #expect(
            AquamarineAskFitLog.remainingRestSeconds(snapshot: running, now: now) == 90
        )
        #expect(
            AquamarineAskFitLog.restRemainingDialog(snapshot: running, now: now)
                == "Rest remaining: 1 minute, 30 seconds."
        )
        #expect(
            AquamarineAskFitLog.skipRestDialog(snapshot: running, now: now)
                == "Skipping rest. 1 minute, 30 seconds remaining."
        )

        let expired = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [],
            displayUnit: .pounds,
            restEndsAt: now.addingTimeInterval(-1),
            now: now
        )
        #expect(expired.restEndsAtEpoch == nil)
        #expect(AquamarineAskFitLog.canSkipRest(snapshot: expired, now: now) == false)
        #expect(
            AquamarineAskFitLog.restRemainingDialog(snapshot: expired, now: now)
                == AquamarineAskFitLog.noRestTimerDialog
        )
        #expect(
            AquamarineAskFitLog.skipRestDialog(snapshot: expired, now: now)
                == AquamarineAskFitLog.noRestTimerDialog
        )
    }

    @Test func restRemainingWithoutTimerStaysQuiet() {
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 60,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = AquamarineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [],
            displayUnit: .pounds,
            restEndsAt: nil
        )
        #expect(AquamarineAskFitLog.canSkipRest(snapshot: snapshot) == false)
        #expect(
            AquamarineAskFitLog.restRemainingDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noRestTimerDialog
        )
        #expect(
            AquamarineAskFitLog.skipRestDialog(snapshot: snapshot)
                == AquamarineAskFitLog.noRestTimerDialog
        )
    }

    @Test func aquamarineSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.AquamarineSessionSnapshot(
            inProgressWorkoutName: "Push A",
            lastWeightExerciseName: "Bench Press",
            lastWeightCaption: "185 lb × 8 reps",
            canApplyLastWeight: true,
            restEndsAtEpoch: 1_783_000_000
        )
        FitLogIntentBridge.publishAquamarineSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadAquamarineSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueUseLastWeight()
        #expect(FitLogIntentBridge.consumePendingUseLastWeight())
        #expect(FitLogIntentBridge.consumePendingUseLastWeight() == false)

        FitLogIntentBridge.queueSkipRest()
        #expect(FitLogIntentBridge.consumePendingSkipRest())
        #expect(FitLogIntentBridge.consumePendingSkipRest() == false)

        let ends = Date(timeIntervalSince1970: 1_783_000_090)
        FitLogIntentBridge.publishRestEndsAt(ends)
        #expect(FitLogIntentBridge.loadRestEndsAt() == ends)
        FitLogIntentBridge.publishRestEndsAt(nil)
        #expect(FitLogIntentBridge.loadRestEndsAt() == nil)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        activeExerciseIds: [UUID] = [],
        exercises: [(String, UUID, Int, CardioPrescription?, [LoggedSet])]
    ) -> WorkoutSession {
        let logs: [ExerciseLog] = exercises.map { exerciseName, exerciseId, recommendedSets, cardio, sets in
            let workoutExercise = WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: exerciseId,
                    nameAtTimeOfLog: exerciseName
                )),
                recommendedSets: recommendedSets,
                cardioPrescription: cardio
            )
            return ExerciseLog(
                id: UUID(),
                workoutExercise: workoutExercise,
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
            activeExerciseIds: activeExerciseIds
        )
    }
}
