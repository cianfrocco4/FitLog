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
            intent: LastWorkoutQueryIntent(),
            phrases: [
                "Last workout in \(.applicationName)",
                "What was my last workout in \(.applicationName)"
            ],
            shortTitle: "Last Workout",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: LastLoadQueryIntent(),
            phrases: [
                "Last weight in \(.applicationName)",
                "What was my last weight in \(.applicationName)",
                "Last cardio in \(.applicationName)"
            ],
            shortTitle: "Last Weight",
            systemImageName: "scalemass"
        )
    }
}
