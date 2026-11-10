//
//  FitLogShortcutsProvider.swift
//  FitLog
//
//  App Shortcuts provider for FitLog (Task 30).
//

import Foundation
import AppIntents

struct FitLogShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start workout in \(.applicationName)",
                "Begin training in \(.applicationName)",
                "Start lifting in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
        
        AppShortcut(
            intent: LogSetIntent(),
            phrases: [
                "Log set in \(.applicationName)",
                "Record set in \(.applicationName)"
            ],
            shortTitle: "Log Set",
            systemImageName: "checkmark.circle"
        )
        
        AppShortcut(
            intent: RestTimerIntent(),
            phrases: [
                "Start rest timer in \(.applicationName)",
                "Rest timer in \(.applicationName)"
            ],
            shortTitle: "Rest Timer",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: FocusPreviousExerciseIntent(),
            phrases: [
                "Go to previous exercise in \(.applicationName)",
                "Switch to previous exercise in \(.applicationName)",
                "Focus previous exercise in \(.applicationName)"
            ],
            shortTitle: "Go to Previous",
            systemImageName: "arrow.left.circle"
        )

        AppShortcut(
            intent: PreviousExerciseQueryIntent(),
            phrases: [
                "Previous exercise in \(.applicationName)",
                "What's the previous exercise in \(.applicationName)",
                "Which exercise was previous in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise",
            systemImageName: "arrow.uturn.backward"
        )

        AppShortcut(
            intent: ThisExerciseSetsQueryIntent(),
            phrases: [
                "This exercise sets in \(.applicationName)",
                "How many sets on this exercise in \(.applicationName)",
                "Sets on this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Sets",
            systemImageName: "number"
        )
    }
}
