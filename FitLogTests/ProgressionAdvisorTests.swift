//
//  ProgressionAdvisorTests.swift
//  FitLogTests
//
//  Tests for ProgressionAdvisor (Task 31).
//

import XCTest
@testable import FitLog

final class ProgressionAdvisorTests: XCTestCase {
    func testSuggest_CompoundExercise_LinearProgression() {
        let exerciseLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: UUID(),
                    name: "Squat",
                    targetedMuscles: [.quadriceps],
                    exerciseRole: .compound,
                    movementPattern: .squat,
                    configurationOptions: []
                )),
                recommendedSets: 3,
                recommendedReps: "5"
            ),
            loggedSets: []
        )
        
        let lastWorkingSets = [
            LoggedSet(id: UUID(), weight: 135.0, reps: 5, rpe: 8.0, restTime: 180, timestamp: Date(), dropSegments: []),
            LoggedSet(id: UUID(), weight: 135.0, reps: 5, rpe: 8.5, restTime: 180, timestamp: Date(), dropSegments: []),
            LoggedSet(id: UUID(), weight: 135.0, reps: 5, rpe: 9.0, restTime: 180, timestamp: Date(), dropSegments: [])
        ]
        
        let suggestion = ProgressionAdvisor.suggest(
            for: exerciseLog,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: .compound,
            consecutiveMissed: 0
        )
        
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.targetWeight, 140.0, "Should add 5 lbs for compound")
        XCTAssertEqual(suggestion?.targetReps, 5)
    }
    
    func testSuggest_AccessoryExercise_DoubleProgression() {
        let exerciseLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: UUID(),
                    name: "Dumbbell Curl",
                    targetedMuscles: [.biceps],
                    exerciseRole: .accessory,
                    movementPattern: .pull,
                    configurationOptions: []
                )),
                recommendedSets: 3,
                recommendedReps: "8-12"
            ),
            loggedSets: []
        )
        
        let lastWorkingSets = [
            LoggedSet(id: UUID(), weight: 30.0, reps: 12, rpe: 8.0, restTime: 90, timestamp: Date(), dropSegments: []),
            LoggedSet(id: UUID(), weight: 30.0, reps: 12, rpe: 8.0, restTime: 90, timestamp: Date(), dropSegments: []),
            LoggedSet(id: UUID(), weight: 30.0, reps: 12, rpe: 8.5, restTime: 90, timestamp: Date(), dropSegments: [])
        ]
        
        let suggestion = ProgressionAdvisor.suggest(
            for: exerciseLog,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: .accessory,
            consecutiveMissed: 0
        )
        
        XCTAssertNotNil(suggestion)
        // Hit upper bound, should increase weight and reset reps
        XCTAssertEqual(suggestion?.targetWeight, 35.0)
        XCTAssertEqual(suggestion?.targetReps, 8)
    }
    
    func testSuggest_ConsecutiveMisses_Deload() {
        let exerciseLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: UUID(),
                    name: "Bench Press",
                    targetedMuscles: [.chest],
                    exerciseRole: .compound,
                    movementPattern: .push,
                    configurationOptions: []
                )),
                recommendedSets: 3,
                recommendedReps: "5"
            ),
            loggedSets: []
        )
        
        let lastWorkingSets = [
            LoggedSet(id: UUID(), weight: 185.0, reps: 3, rpe: 10.0, restTime: 240, timestamp: Date(), dropSegments: [])
        ]
        
        let suggestion = ProgressionAdvisor.suggest(
            for: exerciseLog,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: .compound,
            consecutiveMissed: 2
        )
        
        XCTAssertNotNil(suggestion)
        XCTAssertLessThan(suggestion!.targetWeight, 185.0, "Should deload after 2 misses")
    }
}
