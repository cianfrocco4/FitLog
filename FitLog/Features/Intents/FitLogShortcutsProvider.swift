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
            intent: UseThisExerciseLastWorkingRestTimeIntent(),
            phrases: [
                "Use this exercise last working rest in \(.applicationName)",
                "Set rest to this exercise last working rest in \(.applicationName)",
                "Use this lift last working rest in \(.applicationName)"
            ],
            shortTitle: "Use This Exercise Last Working Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisExerciseLastWorkingRestQueryIntent(),
            phrases: [
                "This exercise last working rest in \(.applicationName)",
                "What was last working rest this exercise in \(.applicationName)",
                "Last working rest this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Last Working Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ThisExerciseWorkingSetsLoggedQueryIntent(),
            phrases: [
                "This exercise working sets logged in \(.applicationName)",
                "How many working sets this exercise in \(.applicationName)",
                "Working sets logged this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Working Sets Logged",
            systemImageName: "checkmark.circle"
        )
    }
}
