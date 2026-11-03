//
//  LapisAskFitLogTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct LapisAskFitLogTests {

    @Test func resumeQueuesWhenInProgressEvenIfEmptyAndSkipsWarmupCaption() {
        let inProgress = session(
            name: "Push A",
            endedAt: nil,
            duration: 1_800,
            exercises: [
                (
                    "Bench Press",
                    [
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
            ]
        )
        let olderPull = session(
            name: "Pull A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 3_600,
            exercises: [
                (
                    "Barbell Row",
                    [
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
            ]
        )
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: inProgress,
            completedSessions: [olderPull],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.inProgressLoggedSetCount == 2)
        #expect(snapshot.inProgressCaption == "Last 185 lb × 8 reps")
        #expect(snapshot.lastFinishedWorkoutName == "Pull A")
        #expect(snapshot.lastFinishedCaption == "Last 135 lb × 10 reps")
        #expect(snapshot.lastFinishedExerciseLines == ["Barbell Row 135 lb × 10 reps"])
        #expect(LapisAskFitLog.canResume(snapshot: snapshot))
        #expect(
            LapisAskFitLog.resumeWorkoutDialog(snapshot: snapshot)
                == "Resuming Push A. 2 sets logged. Last 185 lb × 8 reps."
        )
        #expect(
            LapisAskFitLog.lastSessionExercisesDialog(snapshot: snapshot)
                == "Last session Pull A in History: Barbell Row 135 lb × 10 reps."
        )
    }

    @Test func emptyInProgressStillResumesAndDoesNotInventExercises() {
        let empty = session(
            name: "Push A",
            endedAt: nil,
            duration: 120,
            exercises: [("Bench Press", [])]
        )
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: empty,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == "Push A")
        #expect(snapshot.inProgressLoggedSetCount == 0)
        #expect(snapshot.inProgressCaption == nil)
        #expect(LapisAskFitLog.canResume(snapshot: snapshot))
        #expect(
            LapisAskFitLog.resumeWorkoutDialog(snapshot: snapshot)
                == "Resuming Push A. Nothing logged yet."
        )
        #expect(
            LapisAskFitLog.lastSessionExercisesDialog(snapshot: snapshot)
                == LapisAskFitLog.noFinishedDialog
        )
        #expect(
            LapisAskFitLog.daysSinceLastWorkoutDialog(snapshot: snapshot)
                == LapisAskFitLog.noFinishedDialog
        )
    }

    @Test func noInProgressDoesNotInventAResumeOrStart() {
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(LapisAskFitLog.canResume(snapshot: snapshot) == false)
        #expect(LapisAskFitLog.canResume(snapshot: nil) == false)
        #expect(
            LapisAskFitLog.resumeWorkoutDialog(snapshot: snapshot)
                == LapisAskFitLog.noInProgressDialog
        )
        #expect(
            LapisAskFitLog.resumeWorkoutDialog(snapshot: nil)
                == LapisAskFitLog.noInProgressDialog
        )
        #expect(
            LapisAskFitLog.lastSessionExercisesDialog(snapshot: nil)
                == LapisAskFitLog.noFinishedDialog
        )
        #expect(
            LapisAskFitLog.daysSinceLastWorkoutDialog(snapshot: nil)
                == LapisAskFitLog.noFinishedDialog
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
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: finished,
            completedSessions: [finished],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(LapisAskFitLog.canResume(snapshot: snapshot) == false)
        #expect(snapshot.lastFinishedWorkoutName == "Legs A")
        #expect(
            LapisAskFitLog.lastSessionExercisesDialog(snapshot: snapshot)
                == "Last session Legs A in History: Back Squat 225 lb × 5 reps."
        )
    }

    @Test func lastSessionExercisesListsMultipleAndCapsSpokenLines() {
        let sets: (Double, Int) -> [LoggedSet] = { weight, reps in
            [
                LoggedSet(
                    id: UUID(),
                    weight: weight,
                    reps: reps,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        }
        let push = session(
            name: "Push A",
            endedAt: Date(),
            duration: 3_600,
            exercises: [
                ("Bench Press", sets(185, 8)),
                ("Incline Press", sets(70, 10)),
                ("Overhead Press", sets(95, 8)),
                ("Lateral Raise", sets(20, 12)),
                ("Tricep Pushdown", sets(50, 12)),
                ("Cable Fly", sets(25, 15)),
                ("Dip", sets(0, 8))
            ]
        )
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [push],
            displayUnit: .pounds
        )
        #expect(snapshot.lastFinishedExerciseLines.count == 7)
        #expect(snapshot.lastFinishedExerciseLines.first == "Bench Press 185 lb × 8 reps")
        #expect(
            LapisAskFitLog.lastSessionExercisesDialog(snapshot: snapshot)
                == "Last session Push A in History: Bench Press 185 lb × 8 reps, Incline Press 70 lb × 10 reps, Overhead Press 95 lb × 8 reps, Lateral Raise 20 lb × 12 reps, Tricep Pushdown 50 lb × 12 reps, and 2 more."
        )
    }

    @Test func lastSessionExercisesUsesCardioDurationAndSkipsPlaceholders() {
        let zone2 = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
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
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [zone2],
            displayUnit: .pounds
        )
        #expect(snapshot.lastFinishedCaption == "Last 45:00")
        #expect(snapshot.lastFinishedExerciseLines == ["Zone 2 45:00"])
        #expect(
            LapisAskFitLog.lastSessionExercisesDialog(snapshot: snapshot)
                == "Last session Zone 2 · 45 min in History: Zone 2 45:00."
        )
    }

    @Test func daysSinceLastWorkoutUsesCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(year: 2026, month: 11, day: 3, calendar: calendar)
        let today = session(
            name: "Push A",
            endedAt: date(year: 2026, month: 11, day: 3, hour: 9, calendar: calendar),
            duration: 3_600,
            exercises: [
                (
                    "Bench Press",
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
        let todaySnapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [today],
            displayUnit: .pounds
        )
        #expect(
            LapisAskFitLog.daysSinceLastWorkoutDialog(
                snapshot: todaySnapshot,
                now: now,
                calendar: calendar
            )
                == "You already trained today. Last workout was Push A. Last 185 lb × 8 reps."
        )

        let yesterday = session(
            name: "Pull A",
            endedAt: date(year: 2026, month: 11, day: 2, hour: 18, calendar: calendar),
            duration: 3_000,
            exercises: [
                (
                    "Barbell Row",
                    [
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
            ]
        )
        let yesterdaySnapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [yesterday],
            displayUnit: .pounds
        )
        #expect(
            LapisAskFitLog.daysSinceLastWorkoutDialog(
                snapshot: yesterdaySnapshot,
                now: now,
                calendar: calendar
            )
                == "You last trained yesterday. Last workout was Pull A. Last 135 lb × 10 reps."
        )

        let older = session(
            name: "Legs A",
            endedAt: date(year: 2026, month: 10, day: 31, hour: 8, calendar: calendar),
            duration: 2_700,
            exercises: [
                (
                    "Back Squat",
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
        let olderSnapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [older],
            displayUnit: .pounds
        )
        #expect(
            LapisAskFitLog.daysSinceLastWorkoutDialog(
                snapshot: olderSnapshot,
                now: now,
                calendar: calendar
            )
                == "You last trained 3 days ago. Last workout was Legs A. Last 225 lb × 5 reps."
        )
    }

    @Test func lastFinishedPrefersNewestCompleted() {
        let olderPush = session(
            name: "Push A",
            endedAt: Date().addingTimeInterval(-86_400),
            duration: 3_600,
            exercises: [
                (
                    "Bench Press",
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
        let newerCardio = session(
            name: "Zone 2 · 45 min",
            endedAt: Date(),
            duration: 45 * 60,
            exercises: [
                (
                    "Zone 2",
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
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: nil,
            completedSessions: [olderPush, newerCardio],
            displayUnit: .pounds
        )
        #expect(snapshot.lastFinishedWorkoutName == "Zone 2 · 45 min")
        #expect(snapshot.lastFinishedExerciseLines == ["Zone 2 45:00"])
    }

    @Test func blankWorkoutNameIsIgnored() {
        let blank = session(
            name: "  ",
            endedAt: nil,
            duration: 60,
            exercises: [
                (
                    "Bench Press",
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
        let snapshot = LapisAskFitLog.querySnapshot(
            inProgress: blank,
            completedSessions: [blank],
            displayUnit: .pounds
        )
        #expect(snapshot.inProgressWorkoutName == nil)
        #expect(LapisAskFitLog.canResume(snapshot: snapshot) == false)
        #expect(snapshot.lastFinishedWorkoutName == nil)
        #expect(
            LapisAskFitLog.resumeWorkoutDialog(snapshot: snapshot)
                == LapisAskFitLog.noInProgressDialog
        )
    }

    @Test func lapisHistorySnapshotRoundTripsThroughIntentBridge() {
        let endedAt = Date(timeIntervalSince1970: 1_762_128_000)
        let original = FitLogIntentBridge.LapisHistorySnapshot(
            inProgressWorkoutName: "Push A",
            inProgressLoggedSetCount: 6,
            inProgressCaption: "Last 185 lb × 8 reps",
            lastFinishedWorkoutName: "Pull A",
            lastFinishedCaption: "Last 135 lb × 10 reps",
            lastFinishedEndedAt: endedAt,
            lastFinishedExerciseLines: ["Barbell Row 135 lb × 10 reps"]
        )
        FitLogIntentBridge.publishLapisHistorySnapshot(original)
        let loaded = FitLogIntentBridge.loadLapisHistorySnapshot()
        #expect(loaded == original)

        FitLogIntentBridge.queueResumeWorkout()
        #expect(FitLogIntentBridge.consumePendingResumeWorkout())
        #expect(FitLogIntentBridge.consumePendingResumeWorkout() == false)
    }

    // MARK: - Fixtures

    private func session(
        name: String,
        endedAt: Date?,
        duration: Int,
        exercises: [(String, [LoggedSet])]
    ) -> WorkoutSession {
        let logs: [ExerciseLog] = exercises.map { exerciseName, sets in
            let workoutExercise = WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: UUID(),
                    nameAtTimeOfLog: exerciseName
                ))
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
            exerciseLogs: logs
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? Date()
    }
}
