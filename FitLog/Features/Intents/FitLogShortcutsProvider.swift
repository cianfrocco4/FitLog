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
            intent: StartNextSavedWorkoutIntent(),
            phrases: [
                "Start next saved workout in \(.applicationName)",
                "Start a different workout in \(.applicationName)",
                "Start the next library workout in \(.applicationName)"
            ],
            shortTitle: "Start Next Saved Workout",
            systemImageName: "arrow.triangle.2.circlepath"
        )

        AppShortcut(
            intent: NextSavedWorkoutQueryIntent(),
            phrases: [
                "What's my next saved workout in \(.applicationName)",
                "Next saved workout in \(.applicationName)",
                "What should I train next in \(.applicationName)"
            ],
            shortTitle: "Next Saved Workout",
            systemImageName: "arrow.right.circle"
        )

        AppShortcut(
            intent: SavedWorkoutsQueryIntent(),
            phrases: [
                "What workouts do I have in \(.applicationName)",
                "My saved workouts in \(.applicationName)",
                "List my workouts in \(.applicationName)"
            ],
            shortTitle: "My Saved Workouts",
            systemImageName: "list.bullet"
        )
    }
}
