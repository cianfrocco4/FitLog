//
//  CollapsedWorkoutBarAccessibility.swift
//  FitLog
//
//  VoiceOver copy for the floating collapsed workout bar.
//

import Foundation

enum CollapsedWorkoutBarAccessibility {
    /// Spoken label for the primary “open logging” control on the collapsed bar.
    static func openLoggingLabel(
        workoutName: String?,
        exerciseName: String?,
        setProgress: String?,
        remainingRestSeconds: Int
    ) -> String {
        var parts = ["Open workout logging"]

        let trimmedWorkout = workoutName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedWorkout.isEmpty {
            parts.append(trimmedWorkout)
        }

        let trimmedExercise = exerciseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedExercise.isEmpty {
            parts.append("Now: \(trimmedExercise)")
        }

        let trimmedProgress = setProgress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedProgress.isEmpty {
            parts.append(trimmedProgress)
        }

        if remainingRestSeconds > 0 {
            let unit = remainingRestSeconds == 1 ? "second" : "seconds"
            parts.append("\(remainingRestSeconds) \(unit) rest remaining")
        }

        return parts.joined(separator: ", ")
    }
}
