//
//  CardioWorkoutExerciseHelpers.swift
//  FitLog
//

import Foundation

enum CardioWorkoutExerciseHelpers {
    /// True when the active row should use cardio logging UI (not weight/reps).
    static func isCardioLoggingRow(_ workoutExercise: WorkoutExercise, exercises: [Exercise]) -> Bool {
        if workoutExercise.effectiveCardioPrescription != nil { return true }
        guard let exerciseId = workoutExercise.exerciseId,
              let exercise = exercises.first(where: { $0.id == exerciseId })
        else { return false }
        return exercise.modality == .cardio
    }

    static func resolvedExercise(
        for workoutExercise: WorkoutExercise,
        exercises: [Exercise]
    ) -> Exercise? {
        guard let exerciseId = workoutExercise.exerciseId else { return nil }
        return exercises.first { $0.id == exerciseId }
    }
}
