//
//  ActiveWorkoutNextUp.swift
//  FitLog
//
//  What comes after the set you just logged (same exercise, next exercise, or finish).
//

import Foundation

/// Resolves the next logging target from session logs. Used by rest copy, the collapsed bar,
/// and VoiceOver after inline quick-log — not by Home/sheet Finish banners.
enum ActiveWorkoutNextUp {
    enum Target: Equatable {
        case sameExercise(name: String)
        case nextExercise(name: String)
        case readyToFinish
        case unknown
    }

    /// Countable exercises all meet their prescribed work sets.
    static func isReadyToFinish(in logs: [ExerciseLog]) -> Bool {
        let countable = logs.filter { !$0.workoutExercise.isSlotPlaceholder }
        guard !countable.isEmpty else { return false }
        return countable.allSatisfy(\.meetsRecommendedSets)
    }

    static func resolve(
        logs: [ExerciseLog],
        currentIndex: Int?,
        displayName: (WorkoutExercise) -> String
    ) -> Target {
        let countable = logs.filter { !$0.workoutExercise.isSlotPlaceholder }
        guard !countable.isEmpty else { return .unknown }

        if countable.allSatisfy(\.meetsRecommendedSets) {
            return .readyToFinish
        }

        if let currentIndex, logs.indices.contains(currentIndex) {
            let current = logs[currentIndex]
            if !current.workoutExercise.isSlotPlaceholder, !current.meetsRecommendedSets {
                return named(.sameExercise, workoutExercise: current.workoutExercise, displayName: displayName)
            }
            if let next = logs.enumerated().first(where: { index, log in
                index > currentIndex
                    && !log.workoutExercise.isSlotPlaceholder
                    && !log.meetsRecommendedSets
            }) {
                return named(.nextExercise, workoutExercise: next.element.workoutExercise, displayName: displayName)
            }
        }

        if let next = logs.first(where: { !$0.workoutExercise.isSlotPlaceholder && !$0.meetsRecommendedSets }) {
            return named(.nextExercise, workoutExercise: next.workoutExercise, displayName: displayName)
        }

        return .unknown
    }

    /// Spoken suffix after a successful log, or `nil` when there is nothing useful to add.
    static func loggedSetProgressNote(target: Target, done: Int, recommended: Int) -> String? {
        switch target {
        case .readyToFinish:
            return "All planned sets logged"
        case .nextExercise(let name):
            return "Next up: \(name)"
        case .sameExercise, .unknown:
            guard recommended > 0 else { return nil }
            return "\(done) of \(recommended) work sets"
        }
    }

    private static func named(
        _ make: (String) -> Target,
        workoutExercise: WorkoutExercise,
        displayName: (WorkoutExercise) -> String
    ) -> Target {
        let name = displayName(workoutExercise).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? .unknown : make(name)
    }
}
