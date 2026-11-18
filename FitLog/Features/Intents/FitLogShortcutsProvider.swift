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
            intent: UseNextLastRestTimeIntent(),
            phrases: [
                "Use next last rest time in \(.applicationName)",
                "Set rest to next last rest in \(.applicationName)",
                "Use the next exercise rest in \(.applicationName)"
            ],
            shortTitle: "Use Next Last Rest Time",
            systemImageName: "arrow.uturn.forward"
        )

        AppShortcut(
            intent: PreviousExercisePrescribedRestQueryIntent(),
            phrases: [
                "Previous exercise prescribed rest in \(.applicationName)",
                "How long should I rest on the previous exercise in \(.applicationName)",
                "Prescribed rest on the previous exercise in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Prescribed Rest",
            systemImageName: "hourglass"
        )

        AppShortcut(
            intent: ThisWorkoutLastRestQueryIntent(),
            phrases: [
                "This workout last rest in \(.applicationName)",
                "How long did I last rest this workout in \(.applicationName)",
                "Last rest this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Rest",
            systemImageName: "timer"
        )
    }
}
