//
//  TourmalineAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct TourmalineAskFitLogTests {

    @Test func lastSetPrefersActiveWorkingSetAndSkipsWarmups() {
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: inProgress,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.lastSetExerciseName == "Bench Press")
        #expect(snapshot.lastSetCaption == "185 lb × 8 reps")
        #expect(snapshot.currentExerciseName == "Bench Press")
        #expect(snapshot.currentExerciseCaption == "Last 185 lb × 8 reps")
        #expect(snapshot.canApplyLastCardio == false)
        #expect(
            TourmalineAskFitLog.lastSetDialog(snapshot: snapshot)
                == "Last set: Bench Press. 185 lb × 8 reps."
        )
        #expect(
            TourmalineAskFitLog.currentExerciseDialog(snapshot: snapshot)
                == "Current exercise: Bench Press. Last 185 lb × 8 reps."
        )
    }

    @Test func currentExerciseStaysOnActiveWhenItIsAlreadyLogged() {
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: inProgress,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.currentExerciseName == "Bench Press")
        #expect(snapshot.lastSetExerciseName == "Bench Press")
        #expect(
            TourmalineAskFitLog.currentExerciseDialog(snapshot: snapshot)
                == "Current exercise: Bench Press. Last 185 lb × 8 reps."
        )
    }

    @Test func emptyInProgressDoesNotInventASetOrCardioLog() {
        let empty = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            exercises: [("Bench Press", UUID(), 3, nil, [])]
        )
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: empty,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.lastSetExerciseName == nil)
        #expect(snapshot.currentExerciseName == "Bench Press")
        #expect(snapshot.currentExerciseCaption == nil)
        #expect(snapshot.canApplyLastCardio == false)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot) == false)
        #expect(
            TourmalineAskFitLog.lastSetDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noLastSetDialog
        )
        #expect(
            TourmalineAskFitLog.currentExerciseDialog(snapshot: snapshot)
                == "Current exercise: Bench Press."
        )
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noUnfinishedCardioDialog
        )
    }

    @Test func noInProgressDoesNotInventADurationOrStart() {
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot) == false)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: nil) == false)
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noInProgressDialog
        )
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: nil)
                == TourmalineAskFitLog.noInProgressDialog
        )
        #expect(
            TourmalineAskFitLog.lastSetDialog(snapshot: nil)
                == TourmalineAskFitLog.noInProgressDialog
        )
        #expect(
            TourmalineAskFitLog.currentExerciseDialog(snapshot: nil)
                == TourmalineAskFitLog.noInProgressDialog
        )
    }

    @Test func completedSessionIsNotTreatedAsInProgress() {
        let finished = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: finished,
            completedSessions: [finished],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot) == false)
        #expect(
            TourmalineAskFitLog.lastSetDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noInProgressDialog
        )
    }

    @Test func warmupsOnlyAreNotALastSet() {
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: warmupOnly,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.lastSetExerciseName == nil)
        #expect(
            TourmalineAskFitLog.lastSetDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noLastSetDialog
        )
    }

    @Test func unfinishedCardioUsesHistoryDuration() {
        let zoneId = UUID()
        let history = session(
            name: "Zone 2 · 45 min",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-86_400),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                        )
                    ]
                )
            ]
        )
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds
        )
        #expect(snapshot.canApplyLastCardio)
        #expect(snapshot.lastCardioExerciseName == "Zone 2")
        #expect(snapshot.lastCardioCaption == "45:00")
        #expect(snapshot.currentExerciseName == "Zone 2")
        #expect(snapshot.currentExerciseCaption == "Last 45:00")
        #expect(snapshot.lastSetExerciseName == nil)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot))
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == "Logged Zone 2. Last 45:00."
        )
        #expect(
            TourmalineAskFitLog.currentExerciseDialog(snapshot: snapshot)
                == "Current exercise: Zone 2. Last 45:00."
        )
        let applyable = TourmalineAskFitLog.applyableLastCardio(
            in: live,
            completedSessions: [history]
        )
        #expect(applyable?.exerciseIndex == 0)
        #expect(applyable?.durationSec == 45 * 60)
    }

    @Test func unfinishedCardioWithoutHistoryDoesNotInventMinutes() {
        let live = session(
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCardioExerciseName == "Zone 2")
        #expect(snapshot.canApplyLastCardio == false)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot) == false)
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noPreviousCardioDialog
        )
        #expect(
            TourmalineAskFitLog.applyableLastCardio(in: live, completedSessions: []) == nil
        )
    }

    @Test func alreadyLoggedCardioIsNotReapplied() {
        let zoneId = UUID()
        let history = session(
            name: "Zone 2 · 45 min",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-86_400),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                        )
                    ]
                )
            ]
        )
        let live = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
                    zoneId,
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
                            cardioMetrics: CardioMetrics(durationSec: 40 * 60, source: .timer)
                        )
                    ]
                )
            ]
        )
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [history],
            displayUnit: .pounds
        )
        #expect(snapshot.canApplyLastCardio == false)
        #expect(snapshot.lastSetExerciseName == "Zone 2")
        #expect(snapshot.lastSetCaption == "40:00")
        #expect(
            TourmalineAskFitLog.lastSetDialog(snapshot: snapshot)
                == "Last set: Zone 2. 40:00."
        )
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noUnfinishedCardioDialog
        )
        #expect(
            TourmalineAskFitLog.applyableLastCardio(in: live, completedSessions: [history]) == nil
        )
    }

    @Test func strengthOnlyIsNotApplyableCardio() {
        let live = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
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
        #expect(
            TourmalineAskFitLog.applyableLastCardio(in: live, completedSessions: []) == nil
        )
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.canApplyLastCardio == false)
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noUnfinishedCardioDialog
        )
    }

    @Test func activeUnfinishedCardioIsPreferred() {
        let zoneId = UUID()
        let intervalsId = UUID()
        let historyZone = session(
            name: "Zone 2 · 45 min",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-86_400),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                        )
                    ]
                )
            ]
        )
        let historyIntervals = session(
            name: "Intervals",
            endedAt: Date().addingTimeInterval(-172_800),
            duration: 20 * 60,
            exercises: [
                (
                    "Intervals",
                    intervalsId,
                    1,
                    CardioPrescription(kind: .intervals, targetDurationSec: 20 * 60),
                    [
                        LoggedSet(
                            id: UUID(),
                            weight: 0,
                            reps: 0,
                            restTime: 0,
                            timestamp: Date().addingTimeInterval(-172_800),
                            setType: .steadyState,
                            cardioMetrics: CardioMetrics(durationSec: 20 * 60, source: .timer)
                        )
                    ]
                )
            ]
        )
        let live = session(
            name: "Cardio Mix",
            endedAt: nil,
            duration: 60,
            activeExerciseIds: [intervalsId],
            exercises: [
                (
                    "Zone 2",
                    zoneId,
                    1,
                    CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60),
                    []
                ),
                (
                    "Intervals",
                    intervalsId,
                    1,
                    CardioPrescription(kind: .intervals, targetDurationSec: 20 * 60),
                    []
                )
            ]
        )
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [historyZone, historyIntervals],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCardioExerciseName == "Intervals")
        #expect(snapshot.lastCardioCaption == "20:00")
        #expect(snapshot.currentExerciseName == "Intervals")
        let applyable = TourmalineAskFitLog.applyableLastCardio(
            in: live,
            completedSessions: [historyZone, historyIntervals]
        )
        #expect(applyable?.exerciseName == "Intervals")
        #expect(applyable?.exerciseIndex == 1)
        #expect(applyable?.durationSec == 20 * 60)
    }

    @Test func placeholdersDoNotBecomeCurrentExercise() {
        let placeholder = WorkoutExercise(
            id: UUID(),
            resolution: .flexible(
                SlotBlueprint(
                    id: UUID(),
                    label: "Cardio",
                    targetedMuscles: [.other],
                    cardioPrescription: CardioPrescription(
                        kind: .steadyState,
                        targetDurationSec: 30 * 60
                    )
                )
            ),
            recommendedSets: 1
        )
        let zone = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: UUID(),
                nameAtTimeOfLog: "Zone 2"
            )),
            recommendedSets: 1,
            cardioPrescription: CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60)
        )
        let workout = Workout(id: UUID(), name: "Cardio Day", exercises: [placeholder, zone])
        let live = WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date().addingTimeInterval(-120),
            endTime: nil,
            exerciseLogs: [
                ExerciseLog(id: UUID(), workoutExercise: placeholder, loggedSets: []),
                ExerciseLog(id: UUID(), workoutExercise: zone, loggedSets: [])
            ]
        )
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: live,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.currentExerciseName == "Zone 2")
        #expect(snapshot.lastCardioExerciseName == "Zone 2")
        #expect(snapshot.canApplyLastCardio == false)
        #expect(
            TourmalineAskFitLog.currentExerciseDialog(snapshot: snapshot)
                == "Current exercise: Zone 2."
        )
    }

    @Test func blankWorkoutNameIsIgnored() {
        let blank = session(
            name: "  ",
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
        let snapshot = TourmalineAskFitLog.querySnapshot(
            inProgress: blank,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot) == false)
        #expect(
            TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
                == TourmalineAskFitLog.noInProgressDialog
        )
    }

    @Test func tourmalineSessionSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.TourmalineSessionSnapshot(
            inProgressWorkoutName: "Zone 2 · 45 min",
            lastSetExerciseName: "Zone 2",
            lastSetCaption: "45:00",
            currentExerciseName: "Zone 2",
            currentExerciseCaption: "Last 45:00",
            lastCardioExerciseName: "Zone 2",
            lastCardioCaption: "45:00",
            canApplyLastCardio: true
        )
        FitLogIntentBridge.publishTourmalineSessionSnapshot(original)
        let loaded = FitLogIntentBridge.loadTourmalineSessionSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueUseLastCardioDuration()
        #expect(FitLogIntentBridge.consumePendingUseLastCardioDuration())
        #expect(FitLogIntentBridge.consumePendingUseLastCardioDuration() == false)
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
