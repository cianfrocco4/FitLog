//
//  HomeActiveWorkoutProgress.swift
//  FitLog
//
//  Progress semantics for the Home in-progress workout card.
//

import Foundation

enum HomeActiveWorkoutProgress {
    /// Exercises that count toward the progress denominator (excludes open placeholders).
    static func countableExerciseCount(in logs: [ExerciseLog]) -> Int {
        logs.filter { !$0.workoutExercise.isSlotPlaceholder }.count
    }

    /// Exercises whose prescribed work sets are all logged. Warm-ups do not count.
    static func completedExerciseCount(in logs: [ExerciseLog]) -> Int {
        logs.filter { log in
            guard !log.workoutExercise.isSlotPlaceholder else { return false }
            return log.meetsRecommendedSets
        }.count
    }

    static func progressFraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}
