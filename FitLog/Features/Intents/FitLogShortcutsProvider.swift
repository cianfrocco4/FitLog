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
            intent: UsePreviousPrescribedRestTimeIntent(),
            phrases: [
                "Use previous prescribed rest time in \(.applicationName)",
                "Set rest to previous prescribed rest in \(.applicationName)",
                "Use previous exercise rest prescription in \(.applicationName)"
            ],
            shortTitle: "Use Previous Prescribed Rest Time",
            systemImageName: "arrow.uturn.backward"
        )

        AppShortcut(
            intent: ThisExerciseLastRestQueryIntent(),
            phrases: [
                "This exercise last rest in \(.applicationName)",
                "How long did I last rest on this exercise in \(.applicationName)",
                "Last rest on this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Last Rest",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisWorkoutExercisesCompletedQueryIntent(),
            phrases: [
                "This workout exercises completed in \(.applicationName)",
                "How many exercises done this workout in \(.applicationName)",
                "Exercises done this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Exercises Completed",
            systemImageName: "checkmark.circle"
        )
    }
}
