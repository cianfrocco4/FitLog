//
//  EmeraldAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct EmeraldAskFitLogTests {

    @Test func startLastStrengthUsesNewestWorkingLoadAndSkipsWarmups() {
        let older = session(
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
        let newer = session(
            name: "Pull A",
            endedAt: Date(),
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
        let snapshot = EmeraldAskFitLog.querySnapshot(
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(snapshot.lastStrengthWorkoutName == "Pull A")
        #expect(snapshot.lastStrengthCaption == "Last 135 lb × 10 reps")
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
                == "Starting Pull A. Last 135 lb × 10 reps."
        )
        #expect(
            EmeraldAskFitLog.lastStrengthLoadDialog(snapshot: snapshot)
                == "Pull A: Last 135 lb × 10 reps."
        )
    }

    @Test func startLastStrengthSkipsCardioOnlyHistory() {
        let strength = session(
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
        let cardio = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
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
        let snapshot = EmeraldAskFitLog.querySnapshot(
            from: [cardio, strength],
            displayUnit: .pounds
        )
        #expect(snapshot.lastStrengthWorkoutName == "Push A")
        #expect(snapshot.lastStrengthCaption == "Last 185 lb × 8 reps")
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
                == "Starting Push A. Last 185 lb × 8 reps."
        )
        #expect(snapshot.lastStrengthCaption == "Last 185 lb × 8 reps")
    }

    @Test func startLastStrengthIgnoresCardioOnlyAndEmptyHistory() {
        let cardio = session(
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
        let snapshot = EmeraldAskFitLog.querySnapshot(from: [cardio], displayUnit: .pounds)
        #expect(snapshot.lastStrengthWorkoutName == nil)
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
                == EmeraldAskFitLog.noStrengthDialog
        )
        #expect(
            EmeraldAskFitLog.lastStrengthLoadDialog(snapshot: nil)
                == EmeraldAskFitLog.noStrengthDialog
        )
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: nil)
                == EmeraldAskFitLog.noStrengthDialog
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
        let snapshot = EmeraldAskFitLog.querySnapshot(from: [logged], displayUnit: .kilograms)
        #expect(snapshot.lastStrengthCaption == expected)
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
                == "Starting Push A. \(expected)."
        )
        #expect(
            EmeraldAskFitLog.lastStrengthLoadDialog(snapshot: snapshot)
                == "Push A: \(expected)."
        )
    }

    @Test func thisWeeksTrainingCountsCompletedSessionsInCalendarWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        let now = Date(timeIntervalSince1970: 1_793_174_400) // 2026-10-28 00:00 UTC (Wed)
        let monday = Date(timeIntervalSince1970: 1_792_972_800) // 2026-10-26
        let lastWeek = Date(timeIntervalSince1970: 1_792_368_000) // 2026-10-19

        let thisWeekPush = session(
            name: "Push A",
            endedAt: monday,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: monday,
                    setType: .working
                )
            ]
        )
        let thisWeekCardio = session(
            name: "Zone 2 · 45 min",
            endedAt: now,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: now,
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )
        let priorWeek = session(
            name: "Pull A",
            endedAt: lastWeek,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: lastWeek,
                    setType: .working
                )
            ]
        )
        let snapshot = EmeraldAskFitLog.querySnapshot(
            from: [thisWeekPush, thisWeekCardio, priorWeek],
            now: now,
            calendar: calendar,
            displayUnit: .pounds
        )
        #expect(snapshot.thisWeekSessionCount == 2)
        #expect(snapshot.thisWeekLastWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.lastStrengthWorkoutName == "Push A")
        #expect(
            EmeraldAskFitLog.thisWeeksTrainingDialog(snapshot: snapshot)
                == "2 sessions this week. Last session: Zone 2 · 45 min."
        )
        #expect(
            EmeraldAskFitLog.lastStrengthLoadDialog(snapshot: snapshot)
                == "Push A: Last 185 lb × 8 reps."
        )
    }

    @Test func thisWeeksTrainingSingularAndEmpty() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_793_174_400)
        let today = session(
            name: "Pull A",
            endedAt: now,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: now,
                    setType: .working
                )
            ]
        )
        let one = EmeraldAskFitLog.querySnapshot(
            from: [today],
            now: now,
            calendar: calendar,
            displayUnit: .pounds
        )
        #expect(one.thisWeekSessionCount == 1)
        #expect(
            EmeraldAskFitLog.thisWeeksTrainingDialog(snapshot: one)
                == "1 session this week. Last session: Pull A."
        )
        #expect(
            EmeraldAskFitLog.thisWeeksTrainingDialog(snapshot: nil)
                == EmeraldAskFitLog.noWeekSessionsDialog
        )

        let lastWeek = session(
            name: "Push A",
            endedAt: Date(timeIntervalSince1970: 1_792_368_000),
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
        let emptyWeek = EmeraldAskFitLog.querySnapshot(
            from: [lastWeek],
            now: now,
            calendar: calendar,
            displayUnit: .pounds
        )
        #expect(emptyWeek.thisWeekSessionCount == 0)
        #expect(
            EmeraldAskFitLog.thisWeeksTrainingDialog(snapshot: emptyWeek)
                == EmeraldAskFitLog.noWeekSessionsDialog
        )
        #expect(emptyWeek.lastStrengthWorkoutName == "Push A")
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
        let snapshot = EmeraldAskFitLog.querySnapshot(from: [open], displayUnit: .pounds)
        #expect(snapshot.lastStrengthWorkoutName == nil)
        #expect(snapshot.thisWeekSessionCount == 0)
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
                == EmeraldAskFitLog.noStrengthDialog
        )
        #expect(
            EmeraldAskFitLog.thisWeeksTrainingDialog(snapshot: snapshot)
                == EmeraldAskFitLog.noWeekSessionsDialog
        )
    }

    @Test func hybridSessionUsesWorkingLoadNotCardioDuration() {
        let hybrid = session(
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
        let snapshot = EmeraldAskFitLog.querySnapshot(from: [hybrid], displayUnit: .pounds)
        #expect(snapshot.lastStrengthWorkoutName == "Pull A")
        #expect(snapshot.lastStrengthCaption == "Last 135 lb × 10 reps")
        #expect(
            EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
                == "Starting Pull A. Last 135 lb × 10 reps."
        )
    }

    @Test func warmupOnlySessionIsNotStrength() {
        let warmup = session(
            name: "Push A",
            endedAt: Date(),
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
        let snapshot = EmeraldAskFitLog.querySnapshot(from: [warmup], displayUnit: .pounds)
        #expect(snapshot.lastStrengthWorkoutName == nil)
        #expect(snapshot.thisWeekSessionCount == 1)
        #expect(
            EmeraldAskFitLog.lastStrengthLoadDialog(snapshot: snapshot)
                == EmeraldAskFitLog.noStrengthDialog
        )
    }

    @Test func emeraldStrengthSnapshotRoundTripsThroughIntentBridge() {
        let original = FitLogIntentBridge.EmeraldStrengthSnapshot(
            lastStrengthWorkoutName: "Pull A",
            lastStrengthCaption: "Last 135 lb × 10 reps",
            thisWeekSessionCount: 2,
            thisWeekLastWorkoutName: "Zone 2 · 45 min"
        )
        FitLogIntentBridge.publishEmeraldStrengthSnapshot(original)
        let loaded = FitLogIntentBridge.loadEmeraldStrengthSnapshot()
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
