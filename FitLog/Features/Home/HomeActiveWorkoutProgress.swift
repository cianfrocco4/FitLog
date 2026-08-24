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

    /// Exercises that meet or exceed their recommended set count via logged sets.
    static func completedExerciseCount(in logs: [ExerciseLog]) -> Int {
        logs.filter { log in
            guard !log.workoutExercise.isSlotPlaceholder else { return false }
            let target = max(1, log.workoutExercise.recommendedSets)
            return log.loggedSets.count >= target
        }.count
    }

    static func progressFraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    /// True when every countable exercise has met its recommended set count.
    static func isReadyToFinish(in logs: [ExerciseLog]) -> Bool {
        let total = countableExerciseCount(in: logs)
        guard total > 0 else { return false }
        return completedExerciseCount(in: logs) >= total
    }

    static func readyToFinishMessage() -> String {
        "All planned sets logged — Finish when you're ready"
    }

    static func restCompleteAnnouncement(nextExerciseName: String?, readyToFinish: Bool) -> String {
        if readyToFinish {
            return "Rest over — all planned sets logged. Finish when you're ready."
        }
        if let nextExerciseName, !nextExerciseName.isEmpty {
            return "Rest over — Next up: \(nextExerciseName)"
        }
        return "Rest over — time for your next set."
    }
}
