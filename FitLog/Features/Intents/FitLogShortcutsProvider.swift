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
            intent: FocusNextExerciseIntent(),
            phrases: [
                "Go to next exercise in \(.applicationName)",
                "Switch to next exercise in \(.applicationName)",
                "Focus next exercise in \(.applicationName)"
            ],
            shortTitle: "Go to Next",
            systemImageName: "arrow.right.circle"
        )

        AppShortcut(
            intent: RemainingExercisesQueryIntent(),
            phrases: [
                "What's left in \(.applicationName)",
                "Remaining exercises in \(.applicationName)",
                "Which exercises are left in \(.applicationName)"
            ],
            shortTitle: "What's Left",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: CurrentWorkoutQueryIntent(),
            phrases: [
                "Current workout in \(.applicationName)",
                "What's my current workout in \(.applicationName)",
                "What workout am I doing in \(.applicationName)"
            ],
            shortTitle: "Current Workout",
            systemImageName: "dumbbell"
        )
    }
}
