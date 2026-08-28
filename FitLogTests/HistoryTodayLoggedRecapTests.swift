//
//  HistoryTodayLoggedRecapTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct HistoryTodayLoggedRecapTests {
    private let calendar = Calendar.current
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 18))!

    @Test func recap_picksLatestCompletedSessionToday() {
        let morning = completedSession(
            name: "Push A",
            start: now.addingTimeInterval(-8 * 3600),
            end: now.addingTimeInterval(-7 * 3600),
            workingSets: 12
        )
        let evening = completedSession(
            name: "Pull A",
            start: now.addingTimeInterval(-90 * 60),
            end: now.addingTimeInterval(-45 * 60),
            workingSets: 9
        )
        let recap = HistoryTodayLoggedRecap.recap(
            from: [morning, evening],
            now: now,
            calendar: calendar
        )
        #expect(recap?.id == evening.id)
        #expect(recap?.workoutName == "Pull A")
        #expect(recap?.workingSetCount == 9)
        #expect(recap?.statsLine.contains("9 working sets") == true)
        #expect(recap?.statsLine.contains("45 min") == true)
    }

    @Test func recap_ignoresYesterdayAndInProgress() {
        let yesterday = completedSession(
            name: "Push A",
            start: now.addingTimeInterval(-26 * 3600),
            end: now.addingTimeInterval(-25 * 3600),
            workingSets: 8
        )
        let inProgress = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Live", exercises: []),
            startTime: now.addingTimeInterval(-600),
            endTime: nil,
            exerciseLogs: []
        )
        #expect(
            HistoryTodayLoggedRecap.recap(
                from: [yesterday, inProgress],
                now: now,
                calendar: calendar
            ) == nil
        )
    }

    @Test func recap_cardioUsesDurationWhenNoWorkingSets() {
        let session = cardioSession(
            name: "Zone 2",
            start: now.addingTimeInterval(-50 * 60),
            end: now.addingTimeInterval(-5 * 60),
            durationSec: 45 * 60
        )
        let recap = HistoryTodayLoggedRecap.recap(
            from: [session],
            now: now,
            calendar: calendar
        )
        #expect(recap?.workoutName == "Zone 2")
        #expect(recap?.workingSetCount == 0)
        #expect(recap?.cardioDurationSeconds == 45 * 60)
        #expect(recap?.statsLine.contains("45 min") == true)
    }

    @Test func durationLabel_formatsHoursAndSeconds() {
        #expect(HistoryTodayLoggedRecap.durationLabel(seconds: 45) == "45s")
        #expect(HistoryTodayLoggedRecap.durationLabel(seconds: 90) == "1 min")
        #expect(HistoryTodayLoggedRecap.durationLabel(seconds: 3660) == "1h 1m")
    }

    private func completedSession(
        name: String,
        start: Date,
        end: Date,
        workingSets: Int
    ) -> WorkoutSession {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let we = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(from: exercise)),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let sets = (0..<workingSets).map { _ in
            LoggedSet(
                id: UUID(),
                weight: 185,
                reps: 8,
                restTime: 90,
                timestamp: start,
                setType: .working
            )
        }
        let log = ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: sets)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: name, exercises: [we]),
            startTime: start,
            endTime: end,
            exerciseLogs: [log]
        )
    }

    private func cardioSession(
        name: String,
        start: Date,
        end: Date,
        durationSec: Int
    ) -> WorkoutSession {
        let exercise = Exercise(id: UUID(), name: "Zone 2", description: "", targetedMuscles: [.other])
        let we = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(from: exercise)),
            defaultRestTime: 0,
            recommendedSets: 1,
            recommendedReps: "—"
        )
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: start,
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: durationSec, distanceM: 6000)
        )
        let log = ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [set])
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: name, exercises: [we], workoutKind: .cardio),
            startTime: start,
            endTime: end,
            exerciseLogs: [log]
        )
    }
}
