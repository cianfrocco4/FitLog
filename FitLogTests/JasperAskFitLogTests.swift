//
//  JasperAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct JasperAskFitLogTests {

    @Test func repeatPrefersActiveWorkingSetAndSkipsWarmups() {
        let benchId = UUID()
        let inclineId = UUID()
        let older = Date().addingTimeInterval(-120)
        let newer = Date()
        let inProgress = session(
            name: "Push A",
            endedAt: nil,
            duration: 1_800,
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
                            timestamp: older,
                            setType: .warmup
                        ),
                        LoggedSet(
                            id: UUID(),
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: older.addingTimeInterval(30),
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
                            timestamp: newer,
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: inProgress,
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.lastRepeatableExerciseName == "Bench Press")
        #expect(snapshot.lastRepeatableCaption == "185 lb × 8 reps")
        #expect(snapshot.remainingSetCount == 4)
        #expect(snapshot.remainingExerciseCount == 2)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseRemainingSets == 2)
        #expect(snapshot.nextExerciseCaption == "Last 185 lb × 8 reps")
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot))
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == "Logged Bench Press again. 185 lb × 8 reps."
        )
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == "4 sets left across 2 exercises."
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: snapshot)
                == "Next up: Bench Press. 2 sets left. Last 185 lb × 8 reps."
        )
    }

    @Test func emptyInProgressDoesNotInventARepeat() {
        let empty = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: empty,
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.lastRepeatableExerciseName == nil)
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(snapshot.remainingSetCount == 3)
        #expect(snapshot.remainingExerciseCount == 1)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(snapshot.nextExerciseRemainingSets == 3)
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == JasperAskFitLog.noRepeatableDialog
        )
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == "3 sets left on Bench Press."
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: snapshot)
                == "Next up: Bench Press. 3 sets left."
        )
    }

    @Test func noInProgressDoesNotInventASetOrStart() {
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: nil,
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: nil) == false)
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == JasperAskFitLog.noInProgressDialog
        )
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: nil)
                == JasperAskFitLog.noInProgressDialog
        )
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: nil)
                == JasperAskFitLog.noInProgressDialog
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: nil)
                == JasperAskFitLog.noInProgressDialog
        )
    }

    @Test func completedSessionIsNotTreatedAsInProgress() {
        let finished = session(
            name: "Legs A",
            endedAt: Date(),
            duration: 2_700,
            exercises: [
                (
                    "Back Squat",
                    UUID(),
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 225,
                            reps: 5,
                            restTime: 120,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: finished,
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == JasperAskFitLog.noInProgressDialog
        )
    }

    @Test func warmupsOnlyAreNotRepeatable() {
        let warmupOnly = session(
            name: "Push A",
            endedAt: nil,
            duration: 300,
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    3,
                    nil,
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 95,
                            reps: 8,
                            restTime: 45,
                            timestamp: Date(),
                            setType: .warmup
                        )
                    ]
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: warmupOnly,
            displayUnit: .pounds
        )
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(snapshot.remainingSetCount == 3)
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == JasperAskFitLog.noRepeatableDialog
        )
    }

    @Test func cardioDurationIsNotAutoRepeatedButCountsAsDone() {
        let cardio = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
                    UUID(),
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date(),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                        )
                    ]
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: cardio,
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Zone 2 · 45 min")
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(snapshot.remainingSetCount == 0)
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == JasperAskFitLog.noRepeatableDialog
        )
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == JasperAskFitLog.allSetsLoggedDialog
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: snapshot)
                == JasperAskFitLog.allSetsLoggedDialog
        )
    }

    @Test func unfinishedCardioIsNextButNotRepeatable() {
        let cardio = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
            duration: 60,
            exercises: [
                (
                    "Zone 2",
                    UUID(),
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    []
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: cardio,
            displayUnit: .pounds
        )
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(snapshot.remainingSetCount == 1)
        #expect(snapshot.nextExerciseName == "Zone 2")
        #expect(snapshot.nextExerciseRemainingSets == 1)
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == "1 set left on Zone 2."
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: snapshot)
                == "Next up: Zone 2. 1 set left."
        )
    }

    @Test func allPrescribedWorkingSetsAreLogged() {
        let done = session(
            name: "Push A",
            endedAt: nil,
            duration: 2_400,
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    2,
                    nil,
                    [
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
                            reps: 7,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: done,
            displayUnit: .pounds
        )
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot))
        #expect(snapshot.lastRepeatableCaption == "185 lb × 7 reps")
        #expect(snapshot.remainingSetCount == 0)
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == JasperAskFitLog.allSetsLoggedDialog
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: snapshot)
                == JasperAskFitLog.allSetsLoggedDialog
        )
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == "Logged Bench Press again. 185 lb × 7 reps."
        )
    }

    @Test func nextFallsThroughWhenActiveExerciseIsDone() {
        let benchId = UUID()
        let inclineId = UUID()
        let inProgress = session(
            name: "Push A",
            endedAt: nil,
            duration: 1_800,
            activeExerciseIds: [benchId],
            exercises: [
                (
                    "Bench Press",
                    benchId,
                    1,
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
                    3,
                    nil,
                    []
                )
            ]
        )
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: inProgress,
            displayUnit: .pounds
        )
        #expect(snapshot.lastRepeatableExerciseName == "Bench Press")
        #expect(snapshot.remainingSetCount == 3)
        #expect(snapshot.remainingExerciseCount == 1)
        #expect(snapshot.nextExerciseName == "Incline Press")
        #expect(snapshot.nextExerciseRemainingSets == 3)
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == "3 sets left on Incline Press."
        )
        #expect(
            JasperAskFitLog.nextExerciseDialog(snapshot: snapshot)
                == "Next up: Incline Press. 3 sets left."
        )
    }

    @Test func blankWorkoutNameIsIgnored() {
        let blank = session(
            name: "  ",
            endedAt: nil,
            duration: 60,
            exercises: [
                (
                    "Bench Press",
                    UUID(),
                    3,
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
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: blank,
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) == false)
        #expect(
            JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
                == JasperAskFitLog.noInProgressDialog
        )
    }

    @Test func placeholdersDoNotCountTowardRemaining() {
        let placeholder = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: UUID(),
                    label: "Chest",
                    targetedMuscles: [.chest]
                )
            ),
            recommendedSets: 3
        )
        let bench = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: UUID(),
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
        let snapshot = JasperAskFitLog.querySnapshot(
            inProgress: live,
            displayUnit: .pounds
        )
        #expect(snapshot.remainingSetCount == 3)
        #expect(snapshot.remainingExerciseCount == 1)
        #expect(snapshot.nextExerciseName == "Bench Press")
        #expect(
            JasperAskFitLog.setsRemainingDialog(snapshot: snapshot)
                == "3 sets left on Bench Press."
        )
    }

    @Test func jasperSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.JasperSessionSnapshot(
            inProgressWorkoutName: "Push A",
            lastRepeatableExerciseName: "Bench Press",
            lastRepeatableCaption: "185 lb × 8 reps",
            remainingSetCount: 4,
            remainingExerciseCount: 2,
            nextExerciseName: "Bench Press",
            nextExerciseRemainingSets: 2,
            nextExerciseCaption: "Last 185 lb × 8 reps"
        )
        FitLogIntentBridge.publishJasperSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadJasperSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueRepeatLastSet()
        #expect(FitLogIntentBridge.consumePendingRepeatLastSet())
        #expect(FitLogIntentBridge.consumePendingRepeatLastSet() == false)
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
