//
//  CardioModelsDecodingTests.swift
//  FitLogTests
//
//  Ensures pre-cardio JSON decodes with strength-safe defaults.
//

import XCTest
@testable import FitLog

final class CardioModelsDecodingTests: XCTestCase {

    func testDecodeLegacyExerciseJSON() throws {
        let json = """
        {"id":"11111111-2222-3333-4444-555555555555","name":"Barbell Bench Press","description":"Flat bench","targetedMuscles":["Chest"],"isCustom":false,"configurationOptions":[],"exerciseRole":"Compound"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let exercise = try JSONDecoder().decode(Exercise.self, from: data)
        XCTAssertEqual(exercise.modality, .strength)
        XCTAssertNil(exercise.cardioMetadata)
    }

    func testDecodeLegacyLoggedSetJSON() throws {
        let json = """
        {"id":"22222222-3333-4444-5555-666666666666","weight":225,"reps":8,"restTime":90,"timestamp":0,"setType":"working","configuration":{},"dropSegments":[]}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let set = try JSONDecoder().decode(LoggedSet.self, from: data)
        XCTAssertNil(set.cardioMetrics)
        XCTAssertFalse(set.isCardioEntry)
        XCTAssertTrue(set.countsTowardVolumeTotals)
        XCTAssertFalse(set.countsTowardCardioTotals)
    }

    func testDecodeLegacyWorkoutJSON() throws {
        let json = """
        {"id":"33333333-4444-5555-6666-777777777777","name":"Push Day","exercises":[],"templateSlotIdByWorkoutExerciseId":{}}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let workout = try JSONDecoder().decode(Workout.self, from: data)
        XCTAssertEqual(workout.workoutKind, .strength)
    }

    func testDecodeLegacySplitBuilderSlotJSON() throws {
        let json = """
        {"id":"44444444-5555-6666-7777-888888888888","label":"Run","targetMuscleNames":[],"sets":1,"reps":"30 min","suggestedExerciseName":null,"suggestedExerciseOverrideId":null}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let slot = try JSONDecoder().decode(SplitBuilderEditableSlot.self, from: data)
        XCTAssertEqual(slot.modality, .strength)
        XCTAssertNil(slot.cardioPrescription)
    }

    func testCardioMetricsRoundTrip() throws {
        let metrics = CardioMetrics(
            durationSec: 1800,
            distanceM: 5000,
            avgPaceSecPerKm: 360,
            avgHeartRate: 152,
            source: .timer
        )
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: metrics
        )
        let data = try JSONEncoder().encode(set)
        let decoded = try JSONDecoder().decode(LoggedSet.self, from: data)
        XCTAssertEqual(decoded.cardioMetrics?.durationSec, 1800)
        XCTAssertEqual(decoded.cardioMetrics?.distanceM, 5000)
        XCTAssertTrue(decoded.isCardioEntry)
        XCTAssertFalse(decoded.countsTowardVolumeTotals)
        XCTAssertTrue(decoded.countsTowardCardioTotals)
    }

    func testWorkoutKindDerivedFromCardioExercise() {
        let runId = UUID()
        let run = Exercise(
            id: runId,
            name: "Outdoor Run",
            description: "",
            targetedMuscles: [.other],
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(activityKind: .run, primaryMetric: .distance, equipment: .outdoor)
        )
        let row = WorkoutExercise(
            id: UUID(),
            exercise: run,
            recommendedSets: 1,
            recommendedReps: "30 min",
            cardioPrescription: CardioPrescription(kind: .steadyState, targetDurationSec: 1800)
        )
        let workout = Workout(id: UUID(), name: "Easy Run", exercises: [row])
        XCTAssertEqual(WorkoutKind.derived(from: workout, exercises: [run]), .cardio)
    }

    func testUnknownExerciseSetTypeDecodesAsWorking() throws {
        let json = "\"unknownKind\""
        let data = try XCTUnwrap(json.data(using: .utf8))
        let setType = try JSONDecoder().decode(ExerciseSetType.self, from: data)
        XCTAssertEqual(setType, .working)
    }
}
