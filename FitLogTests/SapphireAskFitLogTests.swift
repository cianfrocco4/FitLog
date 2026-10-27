//
//  SapphireAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct SapphireAskFitLogTests {

    @Test func startTodaysWorkoutUsesPlanTitleAndLastWorkingLoad() {
        let snapshot = SapphireAskFitLog.querySnapshot(
            from: [
                session(
                    name: "Push A",
                    endedAt: Date().addingTimeInterval(-86_400),
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
                            weight: 185,
                            reps: 8,
                            restTime: 90,
                            timestamp: Date(),
                            setType: .working
                        )
                    ]
                )
            ],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCaptionByWorkoutName["push a"] == "Last 185 lb × 8 reps")
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "Push A", snapshot: snapshot)
                == "Starting Push A. Last 185 lb × 8 reps."
        )
        #expect(SapphireAskFitLog.isStartablePlanTitle("Push A"))
    }

    @Test func startTodaysWorkoutKeepsRestDaysQuiet() {
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "Rest day", snapshot: nil)
                == SapphireAskFitLog.restDayDialog
        )
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "No plan scheduled", snapshot: nil)
                == SapphireAskFitLog.noTodayPlanDialog
        )
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: nil, snapshot: nil)
                == SapphireAskFitLog.noTodayPlanDialog
        )
        #expect(!SapphireAskFitLog.isStartablePlanTitle("Rest day"))
        #expect(!SapphireAskFitLog.isStartablePlanTitle("No plan scheduled"))
        #expect(!SapphireAskFitLog.isStartablePlanTitle("   "))
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "Pull A", snapshot: nil)
                == "Starting Pull A."
        )
    }

    @Test func startTodaysWorkoutUsesMatchingWorkoutCaptionNotLastSession() {
        let push = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
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
        let pull = session(
            name: "Pull A",
            endedAt: Date(),
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
        let snapshot = SapphireAskFitLog.querySnapshot(
            from: [push, pull],
            displayUnit: .pounds
        )
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "Push A", snapshot: snapshot)
                == "Starting Push A. Last 185 lb × 8 reps."
        )
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "Pull A", snapshot: snapshot)
                == "Starting Pull A. Last 135 lb × 10 reps."
        )
    }

    @Test func kilogramsCaptionConvertsStoredPounds() {
        let logged = session(
            name: "Push A",
            endedAt: Date(),
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
        let snapshot = SapphireAskFitLog.querySnapshot(from: [logged], displayUnit: .kilograms)
        #expect(snapshot.lastCaptionByWorkoutName["push a"] == expected)
        #expect(
            SapphireAskFitLog.startTodaysWorkoutDialog(planTitle: "Push A", snapshot: snapshot)
                == "Starting Push A. \(expected)."
        )
    }

    @Test func startLastCardioUsesNewestDurationAndSkipsIntervalRest() {
        let older = session(
            name: "Zone 2 · 20 min",
            endedAt: Date().addingTimeInterval(-86_400),
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 20 * 60, source: .manual)
                )
            ]
        )
        let newer = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .intervalRest,
                    cardioMetrics: CardioMetrics(durationSec: 30, source: .timer)
                ),
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
        let snapshot = SapphireAskFitLog.querySnapshot(
            from: [newer, older],
            displayUnit: .pounds
        )
        #expect(snapshot.lastCardioWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.lastCardioCaption == "Last 45:00")
        #expect(
            SapphireAskFitLog.startLastCardioDialog(snapshot: snapshot)
                == "Starting Zone 2 · 45 min. Last 45:00."
        )
    }

    @Test func startLastCardioIgnoresStrengthOnlyHistory() {
        let strength = session(
            name: "Push A",
            endedAt: Date(),
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
        let snapshot = SapphireAskFitLog.querySnapshot(from: [strength], displayUnit: .pounds)
        #expect(snapshot.lastCardioWorkoutName == nil)
        #expect(
            SapphireAskFitLog.startLastCardioDialog(snapshot: snapshot)
                == SapphireAskFitLog.noCardioDialog
        )
        #expect(
            SapphireAskFitLog.startLastCardioDialog(snapshot: nil)
                == SapphireAskFitLog.noCardioDialog
        )
    }

    @Test func didITrainTodayReportsCompletedSessionOnSameDay() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let today = session(
            name: "Push A",
            endedAt: now,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: now,
                    setType: .working
                )
            ]
        )
        let snapshot = SapphireAskFitLog.querySnapshot(
            from: [today],
            now: now,
            calendar: calendar,
            displayUnit: .pounds
        )
        #expect(snapshot.trainedToday)
        #expect(snapshot.trainedTodayWorkoutName == "Push A")
        #expect(
            SapphireAskFitLog.didITrainTodayDialog(planTitle: "Rest day", snapshot: snapshot)
                == "You already trained today. Last session: Push A."
        )
    }

    @Test func didITrainTodayKeepsRestDaysQuietWhenNothingLogged() {
        let yesterday = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
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
        let snapshot = SapphireAskFitLog.querySnapshot(
            from: [yesterday],
            now: Date(),
            calendar: Calendar(identifier: .gregorian),
            displayUnit: .pounds
        )
        #expect(!snapshot.trainedToday)
        #expect(
            SapphireAskFitLog.didITrainTodayDialog(planTitle: "Rest day", snapshot: snapshot)
                == "Today is a rest day. You have not logged a session."
        )
        #expect(
            SapphireAskFitLog.didITrainTodayDialog(planTitle: "Push A", snapshot: snapshot)
                == "Not yet. Today's workout is Push A."
        )
        #expect(
            SapphireAskFitLog.didITrainTodayDialog(planTitle: "No plan scheduled", snapshot: snapshot)
                == SapphireAskFitLog.notTrainedNoPlanDialog
        )
    }

    @Test func incompleteSessionsAreIgnored() {
        let open = session(
            name: "In progress",
            endedAt: nil,
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
        let snapshot = SapphireAskFitLog.querySnapshot(from: [open], displayUnit: .pounds)
        #expect(!snapshot.trainedToday)
        #expect(snapshot.lastCardioWorkoutName == nil)
        #expect(snapshot.lastCaptionByWorkoutName.isEmpty)
        #expect(
            SapphireAskFitLog.startLastCardioDialog(snapshot: snapshot)
                == SapphireAskFitLog.noCardioDialog
        )
    }

    @Test func sapphireTodaySnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.SapphireTodaySnapshot(
            lastCardioWorkoutName: "Zone 2 · 45 min",
            lastCardioCaption: "Last 45:00",
            trainedToday: true,
            trainedTodayWorkoutName: "Push A",
            lastCaptionByWorkoutName: ["push a": "Last 185 lb × 8 reps"]
        )
        FitLogIntentBridge.publishSapphireTodaySnapshot(original)
        let loaded = FitLogIntentBridge.loadSapphireTodaySnapshot()
        #expect(loaded == original)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
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
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: (endedAt ?? Date()).addingTimeInterval(-3_600),
            endTime: endedAt,
            exerciseLogs: [log]
        )
    }
}
