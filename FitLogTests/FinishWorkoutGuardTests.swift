//
//  FinishWorkoutGuardTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct FinishWorkoutGuardTests {
    @Test func nextFinishStep_requiresConfirmationForEmptyWorkout() {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: []
        )

        let step = CurrentWorkoutSessionViewModel.evaluateFinishStep(
            exerciseLogs: [log],
            cardioFinisherAlreadyOffered: false,
            shouldOfferCardioFinisher: false,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" }
        )

        #expect(step == .confirmEmptyWorkout)
    }

    @Test func nextFinishStep_readyWhenSetsLogged() {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let set = LoggedSet(
            id: UUID(),
            weight: 135,
            reps: 8,
            restTime: 0,
            timestamp: Date(),
            setType: .working
        )
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: [set]
        )

        let step = CurrentWorkoutSessionViewModel.evaluateFinishStep(
            exerciseLogs: [log],
            cardioFinisherAlreadyOffered: true,
            shouldOfferCardioFinisher: true,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" }
        )

        #expect(step == .ready)
    }

    @Test func nextFinishStep_slotPlaceholderOnlyCountsAsEmptyWorkout() {
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .flexible(
                    SlotBlueprint(
                        id: UUID(),
                        label: "Open slot",
                        targetedMuscles: [.chest]
                    )
                ),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: []
        )

        let step = CurrentWorkoutSessionViewModel.evaluateFinishStep(
            exerciseLogs: [log],
            cardioFinisherAlreadyOffered: false,
            shouldOfferCardioFinisher: false,
            displayName: { _ in "Open slot" }
        )

        #expect(step == .confirmEmptyWorkout)
    }
}
