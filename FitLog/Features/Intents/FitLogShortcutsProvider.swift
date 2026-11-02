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
            intent: FinishWorkoutIntent(),
            phrases: [
                "Finish workout in \(.applicationName)",
                "Done with workout in \(.applicationName)",
                "Save my workout in \(.applicationName)"
            ],
            shortTitle: "Finish Workout",
            systemImageName: "flag.checkered"
        )

        AppShortcut(
            intent: InProgressWorkoutQueryIntent(),
            phrases: [
                "Is my workout in progress in \(.applicationName)",
                "What's my current workout in \(.applicationName)",
                "Do I have a workout open in \(.applicationName)"
            ],
            shortTitle: "In-Progress Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )

        AppShortcut(
            intent: LastFinishedWorkoutQueryIntent(),
            phrases: [
                "Last finished workout in \(.applicationName)",
                "What's in History in \(.applicationName)",
                "Did I save my last workout in \(.applicationName)"
            ],
            shortTitle: "Last Finished Workout",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
