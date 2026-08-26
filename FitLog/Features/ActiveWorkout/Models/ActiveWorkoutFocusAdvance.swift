//
//  ActiveWorkoutFocusAdvance.swift
//  FitLog
//
//  After prescribed work sets are in, move focus to the next incomplete exercise
//  so rest can be used to set up the next station.
//

import Foundation

enum ActiveWorkoutFocusAdvance {
    /// Exercise that should become primary after logging on `currentIndex`, or `nil` to keep focus.
    static func nextPrimaryExerciseId(logs: [ExerciseLog], currentIndex: Int) -> UUID? {
        guard logs.indices.contains(currentIndex) else { return nil }
        guard logs[currentIndex].meetsRecommendedSets else { return nil }

        if let ahead = logs.enumerated().first(where: { index, log in
            index > currentIndex
                && !log.workoutExercise.isSlotPlaceholder
                && !log.meetsRecommendedSets
        }) {
            return ahead.element.workoutExercise.exerciseId
        }

        return logs.first {
            !$0.workoutExercise.isSlotPlaceholder && !$0.meetsRecommendedSets
        }?.workoutExercise.exerciseId
    }
}
