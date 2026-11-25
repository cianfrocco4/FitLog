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
            intent: UsePreviousExerciseLastWorkingRestTimeIntent(),
            phrases: [
                "Use previous exercise last working rest in \(.applicationName)",
                "Set rest to previous exercise last working rest in \(.applicationName)",
                "Use last lift last working rest in \(.applicationName)"
            ],
            shortTitle: "Use Previous Exercise Last Working Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: PreviousExerciseLastWorkingRestQueryIntent(),
            phrases: [
                "Previous exercise last working rest in \(.applicationName)",
                "What was last working rest previous exercise in \(.applicationName)",
                "Last working rest previous exercise in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Last Working Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: PreviousExerciseWorkingSetsLoggedQueryIntent(),
            phrases: [
                "Previous exercise working sets logged in \(.applicationName)",
                "How many working sets previous exercise in \(.applicationName)",
                "Working sets logged previous exercise in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Working Sets Logged",
            systemImageName: "checkmark.circle"
        )
    }
}
