//
//  CardioSchemaMigrationTests.swift
//  FitLogTests
//
//  Cardio domain migration backup and normalization tests.
//

import XCTest
@testable import FitLog

final class CardioSchemaMigrationTests: XCTestCase {

    func testNormalizeDerivesStrengthWorkoutKind() {
        let squat = Exercise(id: UUID(), name: "Squat", description: "", targetedMuscles: [.quads])
        var workouts = [
            Workout(id: UUID(), name: "Legs", exercises: [
                WorkoutExercise(id: UUID(), exercise: squat, recommendedSets: 3, recommendedReps: "5")
            ])
        ]
        var sessions: [WorkoutSession] = []
        let changed = CardioSchemaMigration.normalizeInPlace(
            exercises: [squat],
            workouts: &workouts,
            sessions: &sessions
        )
        XCTAssertFalse(changed)
        XCTAssertEqual(workouts.first?.workoutKind, .strength)
    }

    func testBackupRoundTrip() throws {
        let squat = Exercise(id: UUID(), name: "Squat", description: "", targetedMuscles: [.quads])
        let workout = Workout(id: UUID(), name: "Legs", exercises: [
            WorkoutExercise(id: UUID(), exercise: squat, recommendedSets: 3, recommendedReps: "5")
        ])
        let snapshot = BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: [squat],
            workouts: [workout],
            sessions: [],
            program: TrainingProgramState.empty(anchorDayKey: TrainingProgramState.dayKey(for: Date())),
            displayNames: [:]
        )
        XCTAssertTrue(CardioSchemaMigration.writePreMigrationBackupVerified(snapshot))
        XCTAssertTrue(CardioSchemaMigration.validateFullSnapshotCodableRoundTrip(snapshot))
    }

    func testMigrationIdempotentWhenAlreadyStrength() {
        let squat = Exercise(id: UUID(), name: "Squat", description: "", targetedMuscles: [.quads])
        var workouts = [
            Workout(id: UUID(), name: "Legs", exercises: [
                WorkoutExercise(id: UUID(), exercise: squat, recommendedSets: 3, recommendedReps: "5")
            ])
        ]
        var sessions: [WorkoutSession] = []
        let first = CardioSchemaMigration.normalizeInPlace(exercises: [squat], workouts: &workouts, sessions: &sessions)
        let second = CardioSchemaMigration.normalizeInPlace(exercises: [squat], workouts: &workouts, sessions: &sessions)
        XCTAssertFalse(first)
        XCTAssertFalse(second)
    }
}
