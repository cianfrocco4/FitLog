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

    @Test func nextFinishStep_confirmsUnresolvedExercisesBeforeCardioOffer() {
        let logged = makeConcreteLog(name: "Bench Press", sets: [
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 0,
                timestamp: Date(),
                setType: .working
            )
        ])
        let unresolved = makeConcreteLog(name: "Row", sets: [])

        let step = CurrentWorkoutSessionViewModel.evaluateFinishStep(
            exerciseLogs: [logged, unresolved],
            cardioFinisherAlreadyOffered: false,
            shouldOfferCardioFinisher: true,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" }
        )

        #expect(step == .confirmUnresolvedExercises(["Row"]))
    }

    @Test func nextFinishStep_offersCardioFinisherWhenEligible() {
        let logged = makeConcreteLog(name: "Bench Press", sets: [
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 0,
                timestamp: Date(),
                setType: .working
            )
        ])

        let step = CurrentWorkoutSessionViewModel.evaluateFinishStep(
            exerciseLogs: [logged],
            cardioFinisherAlreadyOffered: false,
            shouldOfferCardioFinisher: true,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" }
        )

        #expect(step == .offerCardioFinisher)
    }

    @Test func nextFinishStep_skipsCardioWhenAlreadyOffered() {
        let logged = makeConcreteLog(name: "Bench Press", sets: [
            LoggedSet(
                id: UUID(),
                weight: 135,
                reps: 8,
                restTime: 0,
                timestamp: Date(),
                setType: .working
            )
        ])

        let step = CurrentWorkoutSessionViewModel.evaluateFinishStep(
            exerciseLogs: [logged],
            cardioFinisherAlreadyOffered: true,
            shouldOfferCardioFinisher: true,
            displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" }
        )

        #expect(step == .ready)
    }

    private func makeConcreteLog(name: String, sets: [LoggedSet]) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: name, description: "", targetedMuscles: [.chest])
        return ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: sets
        )
    }
}
