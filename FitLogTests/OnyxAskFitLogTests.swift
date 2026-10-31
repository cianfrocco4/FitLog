//
//  OnyxAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct OnyxAskFitLogTests {

    @Test func nextPlanSkipsRestAndUsesLastWorkingLoadSkippingWarmups() {
        let olderPull = session(
            name: "Pull A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 3_600,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
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
        let newerPush = session(
            name: "Push A",
            endedAt: Date(),
            duration: 2_700,
            sets: [
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
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [olderPull, newerPush],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "Pull A"),
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Saturday", workoutName: "Legs A")
            ],
            thisWeekPlanLines: [
                "Mon Rest",
                "Tue Push A",
                "Wed Rest",
                "Thu Pull A",
                "Fri Rest",
                "Sat Legs A",
                "Sun Rest"
            ],
            displayUnit: .pounds
        )
        #expect(snapshot.upcomingTrainingDays.map(\.workoutName) == ["Pull A", "Legs A"])
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == "Last 135 lb × 10 reps")
        #expect(snapshot.lastCaptionByWorkoutName["push a"] == "Last 185 lb × 8 reps")
        #expect(OnyxAskFitLog.nextTrainingDay(snapshot: snapshot)?.workoutName == "Pull A")
        #expect(OnyxAskFitLog.isStartableNextPlan(snapshot: snapshot))
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A on Thursday. Last 135 lb × 10 reps."
        )
        #expect(
            OnyxAskFitLog.nextPlanWorkoutDialog(snapshot: snapshot)
                == "Next planned workout is Pull A on Thursday. Last 135 lb × 10 reps."
        )
        #expect(
            OnyxAskFitLog.thisWeeksPlanDialog(snapshot: snapshot)
                == "This week's plan: Mon Rest, Tue Push A, Wed Rest, Thu Pull A, Fri Rest, Sat Legs A, Sun Rest."
        )
    }

    @Test func restAndUnscheduledNamesAreDroppedFromUpcoming() {
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Wednesday", workoutName: "Rest day"),
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "  "),
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Friday", workoutName: "No plan scheduled"),
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Saturday", workoutName: "Legs A")
            ],
            thisWeekPlanLines: ["Wed Rest", "Thu —", "Fri —", "Sat Legs A"],
            displayUnit: .pounds
        )
        #expect(snapshot.upcomingTrainingDays.map(\.workoutName) == ["Legs A"])
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Legs A on Saturday."
        )
        #expect(
            OnyxAskFitLog.nextPlanWorkoutDialog(snapshot: snapshot)
                == "Next planned workout is Legs A on Saturday."
        )
    }

    @Test func emptyUpcomingDoesNotStart() {
        let logged = session(
            name: "Push A",
            endedAt: Date(),
            duration: 3_600,
            sets: [
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
        let empty = OnyxAskFitLog.querySnapshot(
            from: [logged],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Friday", workoutName: "Rest")
            ],
            thisWeekPlanLines: ["Mon Rest", "Tue Rest"],
            displayUnit: .pounds
        )
        #expect(empty.upcomingTrainingDays.isEmpty)
        #expect(OnyxAskFitLog.nextTrainingDay(snapshot: empty) == nil)
        #expect(OnyxAskFitLog.isStartableNextPlan(snapshot: empty) == false)
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: empty)
                == OnyxAskFitLog.noUpcomingPlanDialog
        )
        #expect(
            OnyxAskFitLog.nextPlanWorkoutDialog(snapshot: empty)
                == OnyxAskFitLog.noUpcomingPlanDialog
        )
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: nil)
                == OnyxAskFitLog.noUpcomingPlanDialog
        )
        #expect(OnyxAskFitLog.isStartableNextPlan(snapshot: nil) == false)
        #expect(
            OnyxAskFitLog.thisWeeksPlanDialog(snapshot: empty)
                == "This week's plan: Mon Rest, Tue Rest."
        )
    }

    @Test func unscheduledWeekOnlyDoesNotInventAPlan() {
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [],
            upcomingTrainingDays: [],
            thisWeekPlanLines: ["Mon —", "Tue —", "  "],
            displayUnit: .pounds
        )
        #expect(
            OnyxAskFitLog.thisWeeksPlanDialog(snapshot: snapshot)
                == OnyxAskFitLog.noWeekPlanDialog
        )
        #expect(
            OnyxAskFitLog.thisWeeksPlanDialog(snapshot: nil)
                == OnyxAskFitLog.noWeekPlanDialog
        )
    }

    @Test func missingWeekdayStillStartsNamedWorkout() {
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "  ", workoutName: "Push A")
            ],
            thisWeekPlanLines: ["Tue Push A"],
            displayUnit: .pounds
        )
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
        #expect(
            OnyxAskFitLog.nextPlanWorkoutDialog(snapshot: snapshot)
                == "Next planned workout is Push A."
        )
    }

    @Test func kilogramsCaptionConvertsStoredPoundsForNextPlan() {
        let pull = session(
            name: "Pull A",
            endedAt: Date(),
            duration: 3_600,
            sets: [
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
        let kg = WeightStoreConversion.displayValue(storedPounds: 135, unit: .kilograms)
        let expected = "Last \(WeightStoreConversion.formatDisplay(kg)) kg × 10 reps"
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [pull],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "Pull A")
            ],
            thisWeekPlanLines: ["Thu Pull A"],
            displayUnit: .kilograms
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == expected)
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A on Thursday. \(expected)."
        )
        #expect(
            OnyxAskFitLog.nextPlanWorkoutDialog(snapshot: snapshot)
                == "Next planned workout is Pull A on Thursday. \(expected)."
        )
    }

    @Test func incompleteSessionsAreIgnoredForCaptions() {
        let open = session(
            name: "Pull A",
            endedAt: nil,
            duration: 1_800,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 225,
                    reps: 3,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [open],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "Pull A")
            ],
            thisWeekPlanLines: ["Thu Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName.isEmpty)
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A on Thursday."
        )
    }

    @Test func warmupOnlySessionOmitsLoadCaption() {
        let warmup = session(
            name: "Pull A",
            endedAt: Date(),
            duration: 600,
            sets: [
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
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [warmup],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "Pull A")
            ],
            thisWeekPlanLines: ["Thu Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == nil)
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A on Thursday."
        )
    }

    @Test func hybridSessionPrefersWorkingLoadCaption() {
        let hybrid = session(
            name: "Pull A",
            endedAt: Date(),
            duration: 3_900,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 10 * 60, source: .timer)
                )
            ]
        )
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [hybrid],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "Pull A")
            ],
            thisWeekPlanLines: ["Thu Pull A"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == "Last 135 lb × 10 reps")
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A on Thursday. Last 135 lb × 10 reps."
        )
    }

    @Test func cardioNextPlanUsesLastDurationCaption() {
        let zone2 = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            duration: 45 * 60,
            sets: [
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
        let snapshot = OnyxAskFitLog.querySnapshot(
            from: [zone2],
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(
                    weekdayLabel: "Sunday",
                    workoutName: "Zone 2 · 45 min"
                )
            ],
            thisWeekPlanLines: ["Sun Zone 2 · 45 min"],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["zone 2 · 45 min"] == "Last 45:00")
        #expect(
            OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
                == "Starting Zone 2 · 45 min on Sunday. Last 45:00."
        )
        #expect(
            OnyxAskFitLog.nextPlanWorkoutDialog(snapshot: snapshot)
                == "Next planned workout is Zone 2 · 45 min on Sunday. Last 45:00."
        )
    }

    @Test func onyxNextPlanSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.OnyxNextPlanSnapshot(
            upcomingTrainingDays: [
                FitLogIntentBridge.OnyxUpcomingTraining(weekdayLabel: "Thursday", workoutName: "Pull A")
            ],
            thisWeekPlanLines: ["Mon Rest", "Thu Pull A"],
            lastCaptionByWorkoutName: [
                "pull a": "Last 135 lb × 10 reps"
            ]
        )
        FitLogIntentBridge.publishOnyxNextPlanSnapshot(original)
        let loaded = FitLogIntentBridge.loadOnyxNextPlanSnapshot()
        #expect(loaded == original)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let workoutExercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: UUID(),
                nameAtTimeOfLog: "Movement"
            ))
        )
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: workoutExercise,
            loggedSets: sets
        )
        let workout = Workout(id: UUID(), name: name, exercises: [workoutExercise])
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
            exerciseLogs: [log]
        )
    }
}
