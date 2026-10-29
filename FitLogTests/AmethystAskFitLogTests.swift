//
//  AmethystAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct AmethystAskFitLogTests {

    @Test func startTomorrowsWorkoutUsesLastWorkingLoadAndSkipsWarmups() {
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
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [olderPull, newerPush],
            tomorrowPlanTitle: "Pull A",
            displayUnit: .pounds
        )
        #expect(snapshot.tomorrowPlanTitle == "Pull A")
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == "Last 135 lb × 10 reps")
        #expect(snapshot.lastSessionWorkoutName == "Push A")
        #expect(snapshot.lastSessionDurationSeconds == 2_700)
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A. Last 135 lb × 10 reps."
        )
        #expect(
            AmethystAskFitLog.tomorrowsWorkoutDialog(snapshot: snapshot)
                == "Tomorrow's workout is Pull A. Last 135 lb × 10 reps."
        )
        #expect(AmethystAskFitLog.isStartablePlanTitle(snapshot.tomorrowPlanTitle))
    }

    @Test func restDayAndEmptyPlanDoNotStart() {
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
        let rest = AmethystAskFitLog.querySnapshot(
            from: [logged],
            tomorrowPlanTitle: "Rest day",
            displayUnit: .pounds
        )
        #expect(AmethystAskFitLog.isStartablePlanTitle(rest.tomorrowPlanTitle) == false)
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: rest)
                == AmethystAskFitLog.restDayDialog
        )
        #expect(
            AmethystAskFitLog.tomorrowsWorkoutDialog(snapshot: rest)
                == AmethystAskFitLog.restDayDialog
        )

        let none = AmethystAskFitLog.querySnapshot(
            from: [logged],
            tomorrowPlanTitle: "No plan scheduled",
            displayUnit: .pounds
        )
        #expect(AmethystAskFitLog.isStartablePlanTitle(none.tomorrowPlanTitle) == false)
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: none)
                == AmethystAskFitLog.noTomorrowPlanDialog
        )
        #expect(
            AmethystAskFitLog.tomorrowsWorkoutDialog(snapshot: none)
                == AmethystAskFitLog.noTomorrowPlanDialog
        )
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: nil)
                == AmethystAskFitLog.noTomorrowPlanDialog
        )
        #expect(
            AmethystAskFitLog.tomorrowsWorkoutDialog(snapshot: nil)
                == AmethystAskFitLog.noTomorrowPlanDialog
        )
        #expect(AmethystAskFitLog.isStartablePlanTitle(nil) == false)
        #expect(AmethystAskFitLog.isStartablePlanTitle("  ") == false)
    }

    @Test func lastSessionDurationUsesNewestCompletedWallClock() {
        let older = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 4_200,
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
        let newer = session(
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
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [older, newer],
            tomorrowPlanTitle: "Zone 2 · 45 min",
            displayUnit: .pounds
        )
        #expect(snapshot.lastSessionWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.lastSessionDurationSeconds == 45 * 60)
        #expect(snapshot.lastCaptionByWorkoutName["zone 2 · 45 min"] == "Last 45:00")
        #expect(
            AmethystAskFitLog.lastSessionDurationDialog(snapshot: snapshot)
                == "Zone 2 · 45 min lasted 45 minutes."
        )
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
                == "Starting Zone 2 · 45 min. Last 45:00."
        )
        #expect(
            AmethystAskFitLog.lastSessionDurationDialog(snapshot: nil)
                == AmethystAskFitLog.noSessionDialog
        )
    }

    @Test func kilogramsCaptionConvertsStoredPoundsForTomorrowPlan() {
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
        let kg = WeightStoreConversion.displayValue(storedPounds: 185, unit: .kilograms)
        let expected = "Last \(WeightStoreConversion.formatDisplay(kg)) kg × 8 reps"
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [logged],
            tomorrowPlanTitle: "Push A",
            displayUnit: .kilograms
        )
        #expect(snapshot.lastCaptionByWorkoutName["push a"] == expected)
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
                == "Starting Push A. \(expected)."
        )
        #expect(
            AmethystAskFitLog.tomorrowsWorkoutDialog(snapshot: snapshot)
                == "Tomorrow's workout is Push A. \(expected)."
        )
    }

    @Test func incompleteSessionsAreIgnored() {
        let open = session(
            name: "In progress",
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
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [open],
            tomorrowPlanTitle: "Pull A",
            displayUnit: .pounds
        )
        #expect(snapshot.lastSessionWorkoutName == nil)
        #expect(snapshot.lastSessionDurationSeconds == 0)
        #expect(snapshot.lastCaptionByWorkoutName.isEmpty)
        #expect(
            AmethystAskFitLog.lastSessionDurationDialog(snapshot: snapshot)
                == AmethystAskFitLog.noSessionDialog
        )
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A."
        )
        #expect(
            AmethystAskFitLog.tomorrowsWorkoutDialog(snapshot: snapshot)
                == "Tomorrow's workout is Pull A."
        )
    }

    @Test func hybridSessionPrefersWorkingLoadCaptionAndKeepsWallDuration() {
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
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [hybrid],
            tomorrowPlanTitle: "Pull A",
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["pull a"] == "Last 135 lb × 10 reps")
        #expect(snapshot.lastSessionDurationSeconds == 3_900)
        #expect(
            AmethystAskFitLog.lastSessionDurationDialog(snapshot: snapshot)
                == "Pull A lasted 1 hour, 5 minutes."
        )
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
                == "Starting Pull A. Last 135 lb × 10 reps."
        )
    }

    @Test func warmupOnlySessionStillReportsDurationWithoutLoadCaption() {
        let warmup = session(
            name: "Push A",
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
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [warmup],
            tomorrowPlanTitle: "Push A",
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["push a"] == nil)
        #expect(snapshot.lastSessionWorkoutName == "Push A")
        #expect(snapshot.lastSessionDurationSeconds == 600)
        #expect(
            AmethystAskFitLog.lastSessionDurationDialog(snapshot: snapshot)
                == "Push A lasted 10 minutes."
        )
        #expect(
            AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
                == "Starting Push A."
        )
    }

    @Test func zeroDurationCompletedSessionOmitsSpokenTime() {
        let instant = session(
            name: "Push A",
            endedAt: Date(),
            duration: 0,
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
        let snapshot = AmethystAskFitLog.querySnapshot(
            from: [instant],
            tomorrowPlanTitle: "Rest day",
            displayUnit: .pounds
        )
        #expect(snapshot.lastSessionDurationSeconds == 0)
        #expect(
            AmethystAskFitLog.lastSessionDurationDialog(snapshot: snapshot)
                == "Last session: Push A."
        )
    }

    @Test func amethystTomorrowSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.AmethystTomorrowSnapshot(
            tomorrowPlanTitle: "Pull A",
            lastCaptionByWorkoutName: ["pull a": "Last 135 lb × 10 reps"],
            lastSessionWorkoutName: "Zone 2 · 45 min",
            lastSessionDurationSeconds: 2_700
        )
        FitLogIntentBridge.publishAmethystTomorrowSnapshot(original)
        let loaded = FitLogIntentBridge.loadAmethystTomorrowSnapshot()
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
