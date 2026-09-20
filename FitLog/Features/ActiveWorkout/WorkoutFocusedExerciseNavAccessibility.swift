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
        positionLabel: String,
        lastLoadCaption: String? = nil
    ) -> String {
        let title = exerciseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let position = positionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastLoad = lastLoadCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var parts: [String] = []
        if !title.isEmpty { parts.append(title) }
        if !position.isEmpty { parts.append(position) }
        if !lastLoad.isEmpty { parts.append(lastLoad) }
        return parts.isEmpty ? "Current exercise" : parts.joined(separator: ", ")
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
