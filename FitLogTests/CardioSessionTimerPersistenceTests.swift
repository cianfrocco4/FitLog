//
//  CardioSessionTimerPersistenceTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class CardioSessionTimerPersistenceTests: XCTestCase {

    func testSteadyTimerEncodesWorkoutExerciseIdNotLegacyIndex() throws {
        let rowId = UUID()
        let state = CardioSteadyTimerState(
            workoutExerciseId: rowId,
            segmentStartedAt: Date(),
            accumulatedSeconds: 42,
            isPaused: false
        )
        let data = try JSONEncoder().encode(state)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["workoutExerciseId"] as? String, rowId.uuidString)
        XCTAssertNil(json?["exerciseIndex"])
    }

    func testSteadyTimerDecodesLegacyExerciseIndex() throws {
        let legacyId = UUID()
        let session = makeSession(workoutExerciseIds: [legacyId])
        let payload: [String: Any] = [
            "exerciseIndex": 0,
            "segmentStartedAt": Date().timeIntervalSince1970,
            "accumulatedSeconds": 10,
            "isPaused": false
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var state = try JSONDecoder().decode(CardioSteadyTimerState.self, from: data)
        XCTAssertTrue(state.resolveWorkoutExerciseId(in: session))
        XCTAssertEqual(state.workoutExerciseId, legacyId)
        XCTAssertNil(state.legacyExerciseIndex)
    }

    func testLegacyIndexOutOfBoundsClearsOnResolve() throws {
        let session = makeSession(workoutExerciseIds: [UUID()])
        let payload: [String: Any] = [
            "exerciseIndex": 99,
            "segmentStartedAt": Date().timeIntervalSince1970,
            "accumulatedSeconds": 0,
            "isPaused": true
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var state = try JSONDecoder().decode(CardioSteadyTimerState.self, from: data)
        XCTAssertFalse(state.resolveWorkoutExerciseId(in: session))
    }

    func testIntervalTimerRoundTripPreservesWorkoutExerciseId() throws {
        let rowId = UUID()
        let spec = CardioIntervalSpec(workDurationSec: 60, restDurationSec: 30, repeatCount: 4)
        let original = CardioIntervalTimerState(
            workoutExerciseId: rowId,
            spec: spec,
            phase: .work,
            currentRound: 2,
            phaseStartedAt: Date(),
            phaseDurationSec: 60,
            isPaused: false,
            pausedRemainingSec: nil
        )
        let decoded = try JSONDecoder().decode(
            CardioIntervalTimerState.self,
            from: try JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded.workoutExerciseId, rowId)
        XCTAssertEqual(decoded.currentRound, 2)
        XCTAssertEqual(decoded.phase, .work)
    }

    private func makeSession(workoutExerciseIds: [UUID]) -> WorkoutSession {
        let exercises = workoutExerciseIds.map { id in
            WorkoutExercise(
                id: id,
                exercise: Exercise(
                    id: UUID(),
                    name: "Run",
                    description: "",
                    targetedMuscles: [],
                    exerciseRole: .accessory,
                    modality: .cardio
                )
            )
        }
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Test", exercises: exercises),
            startTime: Date(),
            exerciseLogs: exercises.map { ExerciseLog(id: UUID(), workoutExercise: $0, loggedSets: []) }
        )
    }
}
