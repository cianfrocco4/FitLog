//
//  HistoryRepeatWorkoutTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HistoryRepeatWorkoutTests {
    @Test func sourceWorkout_prefersLibraryMatchWithExercises() {
        let libraryId = UUID()
        let library = Workout(
            id: libraryId,
            name: "Push A",
            exercises: [row(named: "Bench Press")],
            workoutKind: .strength
        )
        let sessionCopy = Workout(
            id: UUID(),
            name: "Push A",
            exercises: [row(named: "Old bench")],
            workoutKind: .strength
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: sessionCopy,
            startTime: Date(),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(libraryId)
        )

        let source = HistoryRepeatWorkout.sourceWorkout(session: session, library: [library])
        #expect(source?.id == libraryId)
        #expect(source?.name == "Push A")
    }

    @Test func sourceWorkout_fallsBackToSessionWorkoutWhenLibraryMissing() {
        let sessionWorkout = Workout(
            id: UUID(),
            name: "Ad hoc",
            exercises: [row(named: "Squat")],
            workoutKind: .strength
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: sessionWorkout,
            startTime: Date(),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(UUID())
        )

        let source = HistoryRepeatWorkout.sourceWorkout(session: session, library: [])
        #expect(source?.id == sessionWorkout.id)
    }

    @Test func sourceWorkout_skipsEmptyLibraryRow() {
        let libraryId = UUID()
        let emptyLibrary = Workout(id: libraryId, name: "Empty", exercises: [], workoutKind: .strength)
        let sessionWorkout = Workout(
            id: UUID(),
            name: "Logged",
            exercises: [row(named: "Row")],
            workoutKind: .strength
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: sessionWorkout,
            startTime: Date(),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(libraryId)
        )

        let source = HistoryRepeatWorkout.sourceWorkout(session: session, library: [emptyLibrary])
        #expect(source?.id == sessionWorkout.id)
    }

    private func row(named name: String) -> WorkoutExercise {
        WorkoutExercise(
            id: UUID(),
            exercise: Exercise(id: UUID(), name: name, description: "", targetedMuscles: [.chest]),
            recommendedSets: 3,
            recommendedReps: "8"
        )
    }
}
