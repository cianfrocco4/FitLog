//
//  ReadinessDetailLastSessionTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ReadinessDetailLastSessionTests {

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12))!

    @Test func recapLine_usesYesterdayAndWorkoutName() {
        let end = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: []),
            startTime: end.addingTimeInterval(-2700),
            endTime: end,
            exerciseLogs: []
        )
        #expect(
            ReadinessDetailLastSession.recapLine(session: session, now: now)
                == "Last trained yesterday · Push A"
        )
    }

    @Test func detailLine_prefersLastWorkingOverDuration() {
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest])
        let row = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let working = LoggedSet(
            id: UUID(),
            weight: 185,
            reps: 8,
            restTime: 90,
            timestamp: now.addingTimeInterval(-100)
        )
        let warmup = LoggedSet(
            id: UUID(),
            weight: 95,
            reps: 10,
            restTime: 60,
            timestamp: now.addingTimeInterval(-200),
            isWarmup: true
        )
        let end = now.addingTimeInterval(-3600)
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [row]),
            startTime: end.addingTimeInterval(-2700),
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: [warmup, working])]
        )
        let line = ReadinessDetailLastSession.detailLine(session: session, unit: .pounds)
        #expect(line == "Last working: 185 lb × 8")
    }

    @Test func detailLine_fallsBackToWallClockDurationForCardioWithoutLoad() {
        let end = now.addingTimeInterval(-3600)
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Zone 2", exercises: [], workoutKind: .cardio),
            startTime: end.addingTimeInterval(-45 * 60),
            endTime: end,
            exerciseLogs: []
        )
        #expect(
            ReadinessDetailLastSession.detailLine(session: session, unit: .pounds)
                == "Last duration: 45 min"
        )
    }

    @Test func mostRecentCompleted_ignoresInProgress() {
        let done = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Done", exercises: []),
            startTime: now.addingTimeInterval(-7200),
            endTime: now.addingTimeInterval(-3600),
            exerciseLogs: []
        )
        let open = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Open", exercises: []),
            startTime: now.addingTimeInterval(-600),
            endTime: nil,
            exerciseLogs: []
        )
        #expect(ReadinessDetailLastSession.mostRecentCompleted(in: [open, done])?.id == done.id)
    }
}
