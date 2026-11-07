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
            intent: UndoLastSetIntent(),
            phrases: [
                "Undo last set in \(.applicationName)",
                "Undo set in \(.applicationName)",
                "Delete last set in \(.applicationName)"
            ],
            shortTitle: "Undo Last Set",
            systemImageName: "arrow.uturn.backward"
        )

        AppShortcut(
            intent: SetsLoggedQueryIntent(),
            phrases: [
                "Sets logged in \(.applicationName)",
                "How many sets have I logged in \(.applicationName)",
                "What's my set count in \(.applicationName)"
            ],
            shortTitle: "Sets Logged",
            systemImageName: "number"
        )

        AppShortcut(
            intent: ElapsedWorkoutQueryIntent(),
            phrases: [
                "Workout elapsed in \(.applicationName)",
                "How long have I been working out in \(.applicationName)",
                "What's my workout time in \(.applicationName)"
            ],
            shortTitle: "Elapsed Workout",
            systemImageName: "clock"
        )
    }
}
