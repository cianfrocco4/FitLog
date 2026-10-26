//
//  RubyAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct RubyAskFitLogTests {

    @Test func strengthCaptionUsesNewestWorkingSetAndSkipsWarmup() {
        let exerciseId = UUID()
        let older = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
        let newer = session(
            name: "Push A",
            endedAt: Date(),
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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

        let snapshot = RubyAskFitLog.querySnapshot(
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(snapshot.lastWorkoutName == "Push A")
        #expect(snapshot.newestCaption == "Last 185 lb × 8 reps")
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(snapshot: snapshot)
                == "Starting Push A. Last 185 lb × 8 reps."
        )
    }

    @Test func kilogramsCaptionConvertsStoredPounds() {
        let exerciseId = UUID()
        let logged = session(
            name: "Push A",
            endedAt: Date(),
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
        let snapshot = RubyAskFitLog.querySnapshot(from: [logged], displayUnit: .kilograms)
        #expect(snapshot.newestCaption == expected)
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(snapshot: snapshot)
                == "Starting Push A. \(expected)."
        )
    }

    @Test func cardioCaptionUsesNewestDurationAndSkipsIntervalRest() {
        let exerciseId = UUID()
        let older = session(
            name: "Zone 2 · 20 min",
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            exerciseName: "Zone 2",
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
            exerciseId: exerciseId,
            exerciseName: "Zone 2",
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

        let snapshot = RubyAskFitLog.querySnapshot(
            from: [newer, older],
            displayUnit: .pounds
        )
        #expect(snapshot.lastWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.newestCaption == "Last 45:00")
        #expect(snapshot.lastCardioCaption == "Last 45:00")
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(snapshot: snapshot)
                == "Starting Zone 2 · 45 min. Last 45:00."
        )
    }

    @Test func repeatYesterdayDialogHandlesMissingLoadAndEmptyHistory() {
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(
                snapshot: .init(lastWorkoutName: "Push A")
            ) == "Starting Push A."
        )
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(snapshot: nil)
                == RubyAskFitLog.noCompletedWorkoutDialog
        )
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(
                snapshot: .init(lastWorkoutName: "   ")
            ) == RubyAskFitLog.noCompletedWorkoutDialog
        )
    }

    @Test func incompleteSessionsAreIgnored() {
        let exerciseId = UUID()
        let open = session(
            name: "In progress",
            endedAt: nil,
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
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
        let snapshot = RubyAskFitLog.querySnapshot(
            from: [open],
            displayUnit: .pounds
        )
        #expect(snapshot.lastWorkoutName == nil)
        #expect(snapshot.newestCaption == nil)
        #expect(
            RubyAskFitLog.repeatYesterdayDialog(snapshot: snapshot)
                == RubyAskFitLog.noCompletedWorkoutDialog
        )
    }

    @Test func readinessDialogUsesScoreBandAndPlan() {
        let payload = WidgetSnapshotStore.Payload(
            readinessScore: 72,
            readinessSummary: "Good readiness",
            readinessBandTitle: "Good",
            todayPlanTitle: "Push A",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(
            RubyAskFitLog.readinessDialog(payload: payload)
                == "Readiness 72 out of 100. Good. Today: Push A."
        )
        #expect(
            RubyAskFitLog.readinessDialog(payload: nil)
                == RubyAskFitLog.noReadinessDialog
        )
        let planOnly = WidgetSnapshotStore.Payload(
            readinessScore: nil,
            readinessSummary: nil,
            readinessBandTitle: nil,
            todayPlanTitle: "Push A",
            updatedAt: Date()
        )
        #expect(
            RubyAskFitLog.readinessDialog(payload: planOnly)
                == RubyAskFitLog.noReadinessDialog
        )
        let bandOnly = WidgetSnapshotStore.Payload(
            readinessScore: nil,
            readinessSummary: nil,
            readinessBandTitle: "Fair",
            todayPlanTitle: nil,
            updatedAt: Date()
        )
        #expect(
            RubyAskFitLog.readinessDialog(payload: bandOnly)
                == "Readiness. Fair."
        )
    }

    @Test func todayPlanDialogKeepsRestDaysQuiet() {
        #expect(
            RubyAskFitLog.todayPlanDialog(planTitle: "Push A")
                == "Today's workout is Push A."
        )
        #expect(
            RubyAskFitLog.todayPlanDialog(planTitle: "Rest day")
                == RubyAskFitLog.restDayDialog
        )
        #expect(
            RubyAskFitLog.todayPlanDialog(planTitle: "No plan scheduled")
                == RubyAskFitLog.noTodayPlanDialog
        )
        #expect(
            RubyAskFitLog.todayPlanDialog(planTitle: nil)
                == RubyAskFitLog.noTodayPlanDialog
        )
        #expect(
            RubyAskFitLog.todayPlanDialog(planTitle: "   ")
                == RubyAskFitLog.noTodayPlanDialog
        )
    }

    @Test func rubyRepeatSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.RubyRepeatSnapshot(
            lastWorkoutName: "Push A",
            newestCaption: "Last 185 lb × 8 reps",
            lastCardioCaption: "Last 45:00"
        )
        FitLogIntentBridge.publishRubyRepeatSnapshot(original)
        let loaded = FitLogIntentBridge.loadRubyRepeatSnapshot()
        #expect(loaded == original)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        exerciseId: UUID,
        exerciseName: String,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let workoutExercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(
                exerciseId: exerciseId,
                nameAtTimeOfLog: exerciseName
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
