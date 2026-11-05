//
//  WorkoutDurationEstimateTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct WorkoutDurationEstimateTests {

    @Test func liftingOnlyKeepsPerExerciseEstimate() {
        let exercises = (0..<4).map { _ in strengthRow() }
        let estimate = WorkoutDurationEstimate.make(exercises: exercises, library: [])
        #expect(estimate.liftingMinutes == 32)
        #expect(estimate.cardioMinutes == 0)
        #expect(estimate.summary == "~32 min")
    }

    @Test func singleLiftKeepsFifteenMinuteFloor() {
        let estimate = WorkoutDurationEstimate.make(exercises: [strengthRow()], library: [])
        #expect(estimate.liftingMinutes == 15)
        #expect(estimate.summary == "~15 min")
    }

    @Test func cardioPrescriptionIsAddedBesideLifting() {
        let run = WorkoutExercise(
            id: UUID(),
            exercise: Exercise(
                id: UUID(),
                name: "Run",
                description: "",
                targetedMuscles: [],
                modality: .cardio
            ),
            recommendedSets: 1,
            cardioPrescription: CardioPrescription(kind: .steadyState, targetDurationSec: 30 * 60)
        )
        let estimate = WorkoutDurationEstimate.make(
            exercises: [strengthRow(), strengthRow(), run],
            library: []
        )
        #expect(estimate.liftingMinutes == 16)
        #expect(estimate.cardioMinutes == 30)
        #expect(estimate.summary == "~46 min · 16 lifting · 30 cardio")
    }

    @Test func cardioOnlyUsesPrescriptionNotLiftingFloor() {
        let ride = WorkoutExercise(
            id: UUID(),
            exercise: Exercise(
                id: UUID(),
                name: "Bike",
                description: "",
                targetedMuscles: [],
                modality: .cardio
            ),
            recommendedSets: 1,
            cardioPrescription: CardioPrescription(kind: .steadyState, targetDurationSec: 45 * 60)
        )
        let estimate = WorkoutDurationEstimate.make(exercises: [ride], library: [])
        #expect(estimate.liftingMinutes == 0)
        #expect(estimate.cardioMinutes == 45)
        #expect(estimate.summary == "~45 min cardio")
    }

    @Test func intervalsWithoutTargetDurationStillCount() {
        let spec = CardioIntervalSpec(workDurationSec: 30, restDurationSec: 30, repeatCount: 8)
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Intervals")),
            recommendedSets: 1,
            cardioPrescription: CardioPrescription(kind: .intervals, intervals: [spec])
        )
        #expect(WorkoutDurationEstimate.cardioSeconds(for: row) == 480)
        #expect(WorkoutDurationEstimate.minutes(fromSeconds: 480) == 8)
    }

    @Test func cardioModalityWithoutPrescriptionUsesFallback() {
        let exercise = Exercise(
            id: UUID(),
            name: "Row",
            description: "",
            targetedMuscles: [],
            modality: .cardio
        )
        let row = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 1)
        let estimate = WorkoutDurationEstimate.make(exercises: [row], library: [exercise])
        #expect(estimate.cardioMinutes == 20)
        #expect(estimate.summary == "~20 min cardio")
    }

    private func strengthRow() -> WorkoutExercise {
        WorkoutExercise(
            id: UUID(),
            exercise: Exercise(id: UUID(), name: "Squat", description: "", targetedMuscles: [.quads]),
            recommendedSets: 3
        )
    }
}
