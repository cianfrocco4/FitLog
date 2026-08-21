//
//  HomeLastSessionStatsTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HomeLastSessionStatsTests {
    @Test func prefersCardioMetricsOverWallClock() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(3600)
        let exercise = Exercise(
            id: UUID(),
            name: "Easy run",
            description: "",
            targetedMuscles: [],
            exerciseRole: .accessory,
            modality: .cardio
        )
        let row = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 1, recommendedReps: "1")
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: end,
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .manual)
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Zone 2", exercises: [row], workoutKind: .cardio),
            startTime: start,
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: [set])]
        )
        #expect(
            HomeLastSessionStats.durationSeconds(from: session, exercises: [exercise]) == 45 * 60
        )
    }

    @Test func fallsBackToWallClockForCardioWithoutMetrics() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(50 * 60)
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Zone 2", exercises: [], workoutKind: .cardio),
            startTime: start,
            endTime: end,
            exerciseLogs: []
        )
        #expect(HomeLastSessionStats.durationSeconds(from: session, exercises: []) == 50 * 60)
    }

    @Test func ignoresStrengthWallClockWithoutCardioMetrics() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let end = start.addingTimeInterval(3600)
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: [], workoutKind: .strength),
            startTime: start,
            endTime: end,
            exerciseLogs: []
        )
        #expect(HomeLastSessionStats.durationSeconds(from: session, exercises: []) == nil)
    }
}
