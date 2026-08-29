//
//  LastCompletedSessionCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct LastCompletedSessionCopyTests {

    @Test func widgetLines_usesLatestCompletedAndTodayDuration() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 18))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let older = makeStrengthSession(
            name: "Pull A",
            endedAt: yesterday,
            duration: 3600,
            weight: 135,
            reps: 8
        )
        let latest = makeStrengthSession(
            name: "Push A",
            endedAt: today,
            duration: 3120,
            weight: 185,
            reps: 6
        )

        let lines = LastCompletedSessionCopy.widgetLines(
            sessions: [older, latest],
            now: today,
            calendar: calendar
        )

        #expect(lines?.title == "Push A")
        #expect(lines?.subtitle == "Today · 52 min")
    }

    @Test func widgetLines_prefersLoggedCardioDuration() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 18))!
        let session = makeCardioSession(
            name: "Zone 2",
            endedAt: today,
            wallDuration: 3_000,
            cardioDuration: 2_700
        )

        let lines = LastCompletedSessionCopy.widgetLines(
            sessions: [session],
            now: today,
            calendar: calendar
        )

        #expect(lines?.title == "Zone 2")
        #expect(lines?.subtitle == "Today · 45 min")
    }

    @Test func relativeDayLabel_yesterdayAndDaysAgo() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 12))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let threeDays = calendar.date(byAdding: .day, value: -3, to: now)!

        #expect(
            LastCompletedSessionCopy.relativeDayLabel(endingAt: yesterday, now: now, calendar: calendar)
                == "Yesterday"
        )
        #expect(
            LastCompletedSessionCopy.relativeDayLabel(endingAt: threeDays, now: now, calendar: calendar)
                == "3d ago"
        )
    }

    @Test func exploreRecap_cardioShowsDurationNotTrends() {
        let session = makeCardioSession(
            name: "Zone 2",
            endedAt: Date(),
            wallDuration: 3_000,
            cardioDuration: 2_700
        )
        let recap = LastCompletedSessionCopy.exploreRecap(
            latestSession: session,
            unit: .pounds
        )
        #expect(recap == "Last duration: 45 min")
    }

    @Test func exploreRecap_strengthShowsLastWorkingLoad() {
        let session = makeStrengthSession(
            name: "Push A",
            endedAt: Date(),
            duration: 3600,
            weight: 185,
            reps: 8
        )
        let recap = LastCompletedSessionCopy.exploreRecap(
            latestSession: session,
            unit: .pounds
        )
        #expect(recap == "Last working: 185 lb × 8")
    }

    @Test func exploreRecap_skipsWarmUpForLastWorking() {
        let end = Date()
        let exercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let warmup = LoggedSet(
            id: UUID(),
            weight: 95,
            reps: 8,
            restTime: 60,
            timestamp: end.addingTimeInterval(-120),
            setType: .warmup
        )
        let working = LoggedSet(
            id: UUID(),
            weight: 185,
            reps: 5,
            restTime: 90,
            timestamp: end,
            setType: .working
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: []),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: exercise, loggedSets: [warmup, working])]
        )

        #expect(
            LastCompletedSessionCopy.lastWorkingLoadLabel(from: session, unit: .pounds)
                == "185 lb × 5"
        )
    }

    @Test func widgetLines_ignoresInProgressSession() {
        let open = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "In progress", exercises: []),
            startTime: Date(),
            endTime: nil,
            exerciseLogs: []
        )
        #expect(LastCompletedSessionCopy.widgetLines(sessions: [open]) == nil)
    }

    @Test func compactDuration_hours() {
        #expect(LastCompletedSessionCopy.compactDurationLabel(3_600) == "1h")
        #expect(LastCompletedSessionCopy.compactDurationLabel(3_900) == "1h 5m")
        #expect(LastCompletedSessionCopy.compactDurationLabel(120) == "2 min")
    }

    private func makeStrengthSession(
        name: String,
        endedAt: Date,
        duration: TimeInterval,
        weight: Double,
        reps: Int
    ) -> WorkoutSession {
        let exercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let set = LoggedSet(
            id: UUID(),
            weight: weight,
            reps: reps,
            restTime: 90,
            timestamp: endedAt,
            setType: .working
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: name, exercises: []),
            startTime: endedAt.addingTimeInterval(-duration),
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: exercise, loggedSets: [set])]
        )
    }

    private func makeCardioSession(
        name: String,
        endedAt: Date,
        wallDuration: TimeInterval,
        cardioDuration: Int
    ) -> WorkoutSession {
        let exercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Treadmill")),
            defaultRestTime: 0,
            recommendedSets: 1,
            recommendedReps: "—"
        )
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: endedAt,
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: cardioDuration, source: .manual)
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: name, exercises: [], workoutKind: .cardio),
            startTime: endedAt.addingTimeInterval(-wallDuration),
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: exercise, loggedSets: [set])]
        )
    }
}
