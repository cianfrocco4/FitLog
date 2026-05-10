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
                    nameAtTimeOfLog: "Squat"
                )),
                defaultRestTime: 180,
                recommendedSets: 3,
                recommendedReps: "5"
            ),
            loggedSets: []
        )
        
        let lastWorkingSets = [
            LoggedSet(id: UUID(), weight: 135.0, reps: 5, restTime: 180, timestamp: Date(), setType: .working, rpe: 8.0),
            LoggedSet(id: UUID(), weight: 135.0, reps: 5, restTime: 180, timestamp: Date(), setType: .working, rpe: 8.5),
            LoggedSet(id: UUID(), weight: 135.0, reps: 5, restTime: 180, timestamp: Date(), setType: .working, rpe: 9.0)
        ]
        
        let suggestion = ProgressionAdvisor.suggest(
            for: exerciseLog,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: .compound,
            consecutiveMissed: 0
        )
        
        XCTAssertNotNil(suggestion)
        XCTAssertEqual(suggestion?.weight, 140.0, "Should add 5 lbs for compound")
        XCTAssertEqual(suggestion?.reps, 5)
    }
    
    func testSuggest_AccessoryExercise_DoubleProgression() {
        let exerciseLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: UUID(),
                    nameAtTimeOfLog: "Dumbbell Curl"
                )),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8-12"
            ),
            loggedSets: []
        )
        
        let lastWorkingSets = [
            LoggedSet(id: UUID(), weight: 30.0, reps: 12, restTime: 90, timestamp: Date(), setType: .working, rpe: 8.0),
            LoggedSet(id: UUID(), weight: 30.0, reps: 12, restTime: 90, timestamp: Date(), setType: .working, rpe: 8.0),
            LoggedSet(id: UUID(), weight: 30.0, reps: 12, restTime: 90, timestamp: Date(), setType: .working, rpe: 8.5)
        ]
        
        let suggestion = ProgressionAdvisor.suggest(
            for: exerciseLog,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: .accessory,
            consecutiveMissed: 0
        )
        
        XCTAssertNotNil(suggestion)
        // Hit upper bound, should increase weight and reset reps
        XCTAssertEqual(suggestion?.weight, 35.0)
        XCTAssertEqual(suggestion?.reps, 8)
    }
    
    func testSuggest_ConsecutiveMisses_Deload() {
        let exerciseLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(
                    exerciseId: UUID(),
                    nameAtTimeOfLog: "Bench Press"
                )),
                defaultRestTime: 240,
                recommendedSets: 3,
                recommendedReps: "5"
            ),
            loggedSets: []
        )
        
        let lastWorkingSets = [
            LoggedSet(id: UUID(), weight: 185.0, reps: 3, restTime: 240, timestamp: Date(), setType: .working, rpe: 10.0)
        ]
        
        let suggestion = ProgressionAdvisor.suggest(
            for: exerciseLog,
            lastWorkingSets: lastWorkingSets,
            exerciseRole: .compound,
            consecutiveMissed: 2
        )
        
        XCTAssertNotNil(suggestion)
        XCTAssertLessThan(suggestion!.weight, 185.0, "Should deload after 2 misses")
    }
}
