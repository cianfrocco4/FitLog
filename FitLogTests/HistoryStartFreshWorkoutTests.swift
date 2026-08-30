//
//  HistoryStartFreshWorkoutTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct HistoryStartFreshWorkoutTests {

    @Test func sourceWorkout_prefersLibraryMatchFromPlanOrigin() {
        let libraryId = UUID()
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest], isCustom: false)
        let libraryRow = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 4, recommendedReps: "8")
        let library = Workout(id: libraryId, name: "Push A", exercises: [libraryRow])
        let sessionRow = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A (session)", exercises: [sessionRow]),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(libraryId)
        )
        let source = HistoryStartFreshWorkout.sourceWorkout(session: session, library: [library])
        #expect(source?.id == libraryId)
        #expect(source?.exercises.first?.recommendedSets == 4)
    }

    @Test func sourceWorkout_fallsBackToSessionWorkoutWhenLibraryMissing() {
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest], isCustom: false)
        let row = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let sessionWorkout = Workout(id: UUID(), name: "Ad hoc", exercises: [row])
        let session = WorkoutSession(
            id: UUID(),
            workout: sessionWorkout,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(UUID())
        )
        let source = HistoryStartFreshWorkout.sourceWorkout(session: session, library: [])
        #expect(source?.id == sessionWorkout.id)
    }

    @Test func sourceWorkout_nilWhenNoExercises() {
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Empty", exercises: []),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            exerciseLogs: []
        )
        #expect(HistoryStartFreshWorkout.sourceWorkout(session: session, library: []) == nil)
    }
}
