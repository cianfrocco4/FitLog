//
//  HomeLastWorkingLoadTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HomeLastWorkingLoadTests {
    @Test func snapshot_usesLatestWorkingSetNotWarmup() {
        let bench = exercise(named: "Bench Press")
        let row = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "5")
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let warmup = LoggedSet(
            id: UUID(),
            weight: 135,
            reps: 8,
            restTime: 0,
            timestamp: start.addingTimeInterval(60),
            setType: .warmup
        )
        let working = LoggedSet(
            id: UUID(),
            weight: 185,
            reps: 5,
            restTime: 0,
            timestamp: start.addingTimeInterval(180),
            setType: .working
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [row], workoutKind: .strength),
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: [warmup, working])]
        )

        let snap = HomeLastWorkingLoad.snapshot(from: session)
        #expect(snap?.weightPounds == 185)
        #expect(snap?.reps == 5)
        #expect(snap?.exerciseName == "Bench Press")
    }

    @Test func snapshot_prefersLaterExerciseWhenTimestampsTie() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let stamp = start.addingTimeInterval(120)
        let benchRow = WorkoutExercise(
            id: UUID(),
            exercise: exercise(named: "Bench Press"),
            recommendedSets: 3,
            recommendedReps: "5"
        )
        let ohpRow = WorkoutExercise(
            id: UUID(),
            exercise: exercise(named: "Overhead Press"),
            recommendedSets: 3,
            recommendedReps: "6"
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [benchRow, ohpRow], workoutKind: .strength),
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: benchRow,
                    loggedSets: [set(weight: 185, reps: 5, at: stamp)]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: ohpRow,
                    loggedSets: [set(weight: 95, reps: 6, at: stamp)]
                )
            ]
        )

        let snap = HomeLastWorkingLoad.snapshot(from: session)
        #expect(snap?.weightPounds == 95)
        #expect(snap?.exerciseName == "Overhead Press")
    }

    @Test func snapshot_forLibraryId_usesMostRecentCompletedSession() {
        let libraryId = UUID()
        let early = completedSession(
            libraryId: libraryId,
            name: "Push A",
            endOffset: 1_800_000_000,
            weight: 175
        )
        let late = completedSession(
            libraryId: libraryId,
            name: "Push A",
            endOffset: 1_800_086_400,
            weight: 190
        )
        let other = completedSession(
            libraryId: UUID(),
            name: "Pull A",
            endOffset: 1_800_172_800,
            weight: 225
        )

        let snap = HomeLastWorkingLoad.snapshot(
            forLibraryWorkoutId: libraryId,
            sessions: [early, other, late]
        )
        #expect(snap?.weightPounds == 190)
    }

    @Test func snapshot_ignoresCardioAndZeroLoad() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let row = WorkoutExercise(
            id: UUID(),
            exercise: exercise(named: "Easy run"),
            recommendedSets: 1,
            recommendedReps: "1"
        )
        let cardio = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: start.addingTimeInterval(60),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .manual)
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Zone 2", exercises: [row], workoutKind: .cardio),
            startTime: start,
            endTime: start.addingTimeInterval(2700),
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: [cardio])]
        )
        #expect(HomeLastWorkingLoad.snapshot(from: session) == nil)
    }

    private func exercise(named name: String) -> Exercise {
        Exercise(id: UUID(), name: name, description: "", targetedMuscles: [.chest])
    }

    private func set(weight: Double, reps: Int, at timestamp: Date) -> LoggedSet {
        LoggedSet(
            id: UUID(),
            weight: weight,
            reps: reps,
            restTime: 0,
            timestamp: timestamp,
            setType: .working
        )
    }

    private func completedSession(
        libraryId: UUID,
        name: String,
        endOffset: TimeInterval,
        weight: Double
    ) -> WorkoutSession {
        let start = Date(timeIntervalSince1970: endOffset)
        let row = WorkoutExercise(
            id: UUID(),
            exercise: exercise(named: "Main lift"),
            recommendedSets: 3,
            recommendedReps: "5"
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: name, exercises: [row], workoutKind: .strength),
            startTime: start,
            endTime: start.addingTimeInterval(3600),
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: row,
                    loggedSets: [set(weight: weight, reps: 5, at: start.addingTimeInterval(120))]
                )
            ],
            sessionPlanOrigin: .workout(libraryId)
        )
    }
}
