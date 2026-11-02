//
//  PeridotAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct PeridotAskFitLogTests {

    @Test func finishQueuesOnlyWhenInProgressHasLoggedSetsAndSkipsWarmupCaption() {
        let inProgress = session(
            name: "Push A",
            endedAt: nil,
            duration: 1_800,
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
        let olderPull = session(
            name: "Pull A",
            endedAt: Date().addingTimeInterval(-86_400),
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
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: inProgress,
            completedSessions: [olderPull],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.inProgressLoggedSetCount == 2)
        #expect(snapshot.inProgressCaption == "Last 185 lb × 8 reps")
        #expect(snapshot.lastFinishedWorkoutName == "Pull A")
        #expect(snapshot.lastFinishedCaption == "Last 135 lb × 10 reps")
        #expect(PeridotAskFitLog.canFinish(snapshot: snapshot))
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
                == "Finishing Push A. 2 sets logged. Last 185 lb × 8 reps."
        )
        #expect(
            PeridotAskFitLog.inProgressWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. 2 sets logged. Last 185 lb × 8 reps."
        )
        #expect(
            PeridotAskFitLog.lastFinishedWorkoutDialog(snapshot: snapshot)
                == "Last finished workout is Pull A in History. Last 135 lb × 10 reps."
        )
    }

    @Test func emptyInProgressDoesNotFinish() {
        let empty = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            sets: []
        )
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: empty,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.inProgressLoggedSetCount == 0)
        #expect(snapshot.inProgressCaption == nil)
        #expect(PeridotAskFitLog.canFinish(snapshot: snapshot) == false)
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
                == PeridotAskFitLog.nothingLoggedDialog
        )
        #expect(
            PeridotAskFitLog.inProgressWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. Nothing logged yet."
        )
        #expect(
            PeridotAskFitLog.lastFinishedWorkoutDialog(snapshot: snapshot)
                == PeridotAskFitLog.noFinishedDialog
        )
    }

    @Test func noInProgressDoesNotInventAFinish() {
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(PeridotAskFitLog.canFinish(snapshot: snapshot) == false)
        #expect(PeridotAskFitLog.canFinish(snapshot: nil) == false)
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
                == PeridotAskFitLog.noInProgressDialog
        )
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: nil)
                == PeridotAskFitLog.noInProgressDialog
        )
        #expect(
            PeridotAskFitLog.inProgressWorkoutDialog(snapshot: nil)
                == PeridotAskFitLog.noInProgressDialog
        )
        #expect(
            PeridotAskFitLog.lastFinishedWorkoutDialog(snapshot: nil)
                == PeridotAskFitLog.noFinishedDialog
        )
    }

    @Test func completedSessionIsNotTreatedAsInProgress() {
        let finished = session(
            name: "Legs A",
            endedAt: Date(),
            duration: 2_700,
            sets: [
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
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: finished,
            completedSessions: [finished],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(snapshot.inProgressLoggedSetCount == 0)
        #expect(PeridotAskFitLog.canFinish(snapshot: snapshot) == false)
        #expect(snapshot.lastFinishedWorkoutName == "Legs A")
        #expect(
            PeridotAskFitLog.lastFinishedWorkoutDialog(snapshot: snapshot)
                == "Last finished workout is Legs A in History. Last 225 lb × 5 reps."
        )
    }

    @Test func singleLoggedSetUsesSingularCopy() {
        let inProgress = session(
            name: "Push A",
            endedAt: nil,
            duration: 600,
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
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: inProgress,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressLoggedSetCount == 1)
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
                == "Finishing Push A. 1 set logged. Last 135 lb × 10 reps."
        )
        #expect(
            PeridotAskFitLog.inProgressWorkoutDialog(snapshot: snapshot)
                == "Push A is in progress. 1 set logged. Last 135 lb × 10 reps."
        )
    }

    @Test func cardioInProgressUsesLastDurationCaption() {
        let zone2 = session(
            name: "Zone 2 · 45 min",
            endedAt: nil,
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
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: zone2,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressCaption == "Last 45:00")
        #expect(PeridotAskFitLog.canFinish(snapshot: snapshot))
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
                == "Finishing Zone 2 · 45 min. 1 set logged. Last 45:00."
        )
        #expect(
            PeridotAskFitLog.inProgressWorkoutDialog(snapshot: snapshot)
                == "Zone 2 · 45 min is in progress. 1 set logged. Last 45:00."
        )
    }

    @Test func lastFinishedPrefersNewestCompletedAndCardioDuration() {
        let olderPush = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
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
        let newerCardio = session(
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
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [olderPush, newerCardio],
            displayUnit: .pounds
        )
        #expect(snapshot.lastFinishedWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.lastFinishedCaption == "Last 45:00")
        #expect(
            PeridotAskFitLog.lastFinishedWorkoutDialog(snapshot: snapshot)
                == "Last finished workout is Zone 2 · 45 min in History. Last 45:00."
        )
    }

    @Test func blankWorkoutNameIsIgnored() {
        let blank = session(
            name: "  ",
            endedAt: nil,
            duration: 60,
            sets: [
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
        let snapshot = PeridotAskFitLog.querySnapshot(
            inProgress: blank,
            completedSessions: [blank],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(PeridotAskFitLog.canFinish(snapshot: snapshot) == false)
        #expect(snapshot.lastFinishedWorkoutName == nil)
        #expect(
            PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
                == PeridotAskFitLog.noInProgressDialog
        )
    }

    @Test func peridotFinishSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.PeridotFinishSnapshot(
            inProgressWorkoutName: "Push A",
            inProgressLoggedSetCount: 6,
            inProgressCaption: "Last 185 lb × 8 reps",
            lastFinishedWorkoutName: "Pull A",
            lastFinishedCaption: "Last 135 lb × 10 reps"
        )
        FitLogIntentBridge.publishPeridotFinishSnapshot(original)
        let loaded = FitLogIntentBridge.loadPeridotFinishSnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueFinishWorkout()
        #expect(FitLogIntentBridge.consumePendingFinishWorkout())
        #expect(FitLogIntentBridge.consumePendingFinishWorkout() == false)
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
