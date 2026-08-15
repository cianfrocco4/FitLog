//
//  WorkoutFocusedExerciseNavAccessibility.swift
//  FitLog
//
//  VoiceOver copy for focused single-exercise prev/next navigation.
//

import Foundation

enum WorkoutFocusedExerciseNavAccessibility {
    /// Spoken summary for the current exercise title + position in the session.
    static func currentExerciseAccessibilityLabel(
        exerciseTitle: String,
        positionLabel: String
    ) -> String {
        let title = exerciseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = positionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        switch (title.isEmpty, position.isEmpty) {
        case (false, false):
            return "\(title), \(position)"
        case (false, true):
            return title
        case (true, false):
            return position
        case (true, true):
            return "Current exercise"
        }
    }

    static func previousHint(canGoPrevious: Bool) -> String {
        canGoPrevious
            ? "Moves to the previous exercise in this workout"
            : "Already on the first exercise"
    }

    static func nextHint(canGoNext: Bool) -> String {
        canGoNext
            ? "Moves to the next exercise in this workout"
            : "Already on the last exercise"
    }
}
