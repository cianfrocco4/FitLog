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
            intent: UseNextPrescribedRestTimeIntent(),
            phrases: [
                "Use next prescribed rest time in \(.applicationName)",
                "Set rest to next prescribed rest in \(.applicationName)",
                "Use next exercise rest prescription in \(.applicationName)"
            ],
            shortTitle: "Use Next Prescribed Rest Time",
            systemImageName: "arrow.uturn.forward"
        )

        AppShortcut(
            intent: ThisWorkoutLastPrescribedRestQueryIntent(),
            phrases: [
                "This workout last prescribed rest in \(.applicationName)",
                "What rest did the last exercise call for in \(.applicationName)",
                "Last prescribed rest this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Prescribed Rest",
            systemImageName: "clock.badge.checkmark"
        )

        AppShortcut(
            intent: ThisWorkoutSetsCompletedQueryIntent(),
            phrases: [
                "This workout sets completed in \(.applicationName)",
                "How many sets done this workout in \(.applicationName)",
                "Sets done this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Sets Completed",
            systemImageName: "checkmark.circle"
        )
    }
}
