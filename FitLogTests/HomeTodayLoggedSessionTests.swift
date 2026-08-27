//
//  HomeTodayLoggedSessionTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct HomeTodayLoggedSessionTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    @Test func recapPicksLatestCompletedSessionToday() {
        let now = Date(timeIntervalSince1970: 1_777_219_200) // 2026-05-01 00:00 UTC
        let older = session(
            name: "Push A",
            start: now.addingTimeInterval(10 * 3600),
            end: now.addingTimeInterval(11 * 3600),
            workingSets: 12
        )
        let newer = session(
            name: "Zone 2",
            start: now.addingTimeInterval(18 * 3600),
            end: now.addingTimeInterval(18 * 3600 + 45 * 60),
            workingSets: 0
        )
        let yesterday = session(
            name: "Legs A",
            start: now.addingTimeInterval(-20 * 3600),
            end: now.addingTimeInterval(-19 * 3600),
            workingSets: 9
        )

        let recap = HomeTodayLoggedSession.recap(
            from: [older, newer, yesterday],
            now: now.addingTimeInterval(20 * 3600),
            calendar: calendar
        )
        #expect(recap?.id == newer.id)
        #expect(recap?.workoutName == "Zone 2")
        #expect(recap?.durationSeconds == 45 * 60)
        #expect(recap?.workingSetCount == 0)
    }

    @Test func recapCountsWorkingSetsAndDuration() {
        let now = Date(timeIntervalSince1970: 1_777_219_200)
        let logged = session(
            name: "Push A",
            start: now.addingTimeInterval(10 * 3600),
            end: now.addingTimeInterval(10 * 3600 + 42 * 60),
            workingSets: 18
        )
        let recap = HomeTodayLoggedSession.recap(
            from: [logged],
            now: now.addingTimeInterval(12 * 3600),
            calendar: calendar
        )
        #expect(recap?.workingSetCount == 18)
        #expect(recap?.durationSeconds == 42 * 60)
        #expect(recap?.statsLine == "42 min · 18 working sets")
    }

    @Test func standaloneCardHiddenWhenPlanCardAlreadyShowsDone() {
        let recap = HomeTodayLoggedSession.Recap(
            id: UUID(),
            workoutName: "Push A",
            durationSeconds: 2400,
            workingSetCount: 12,
            cardioDurationSeconds: 0,
            libraryWorkoutId: UUID()
        )
        #expect(
            HomeTodayLoggedSession.shouldShowStandaloneCard(
                recap: recap,
                isInProgress: false,
                isFirstRunHome: false,
                todayPlanLibraryWorkoutId: recap.libraryWorkoutId
            ) == false
        )
        #expect(
            HomeTodayLoggedSession.shouldShowStandaloneCard(
                recap: recap,
                isInProgress: false,
                isFirstRunHome: false,
                todayPlanLibraryWorkoutId: UUID()
            )
        )
        #expect(
            HomeTodayLoggedSession.shouldShowStandaloneCard(
                recap: recap,
                isInProgress: true,
                isFirstRunHome: false,
                todayPlanLibraryWorkoutId: nil
            ) == false
        )
        #expect(
            HomeTodayLoggedSession.shouldShowStandaloneCard(
                recap: recap,
                isInProgress: false,
                isFirstRunHome: true,
                todayPlanLibraryWorkoutId: nil
            ) == false
        )
    }

    @Test func recapNilWhenNothingCompletedToday() {
        let now = Date(timeIntervalSince1970: 1_777_219_200)
        let yesterday = session(
            name: "Legs A",
            start: now.addingTimeInterval(-20 * 3600),
            end: now.addingTimeInterval(-19 * 3600),
            workingSets: 9
        )
        #expect(
            HomeTodayLoggedSession.recap(
                from: [yesterday],
                now: now.addingTimeInterval(12 * 3600),
                calendar: calendar
            ) == nil
        )
        #expect(HomeTodayLoggedSession.recap(from: [], now: now, calendar: calendar) == nil)
    }
        #expect(HomeTodayLoggedSession.durationLabel(seconds: 45) == "45s")
        #expect(HomeTodayLoggedSession.durationLabel(seconds: 60) == "1 min")
        #expect(HomeTodayLoggedSession.durationLabel(seconds: 42 * 60) == "42 min")
        #expect(HomeTodayLoggedSession.durationLabel(seconds: 3600) == "1h")
        #expect(HomeTodayLoggedSession.durationLabel(seconds: 3660) == "1h 1m")
    }

    private func session(
        name: String,
        start: Date,
        end: Date,
        workingSets: Int
    ) -> WorkoutSession {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let sets = (0..<workingSets).map { _ in
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 90,
                timestamp: start,
                setType: .working
            )
        }
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: sets
        )
        let workoutId = UUID()
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: workoutId, name: name, exercises: []),
            startTime: start,
            endTime: end,
            exerciseLogs: [log],
            sessionPlanOrigin: .workout(workoutId)
        )
    }
}
