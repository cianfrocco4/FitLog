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
            intent: AddRestTimeIntent(),
            phrases: [
                "Add rest time in \(.applicationName)",
                "Add 30 seconds rest in \(.applicationName)",
                "Give me more rest in \(.applicationName)"
            ],
            shortTitle: "Add Rest Time",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ThisExerciseTargetQueryIntent(),
            phrases: [
                "This exercise target in \(.applicationName)",
                "What's the target for this exercise in \(.applicationName)",
                "What should I do on this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Target",
            systemImageName: "target"
        )

        AppShortcut(
            intent: PrescribedRestQueryIntent(),
            phrases: [
                "Prescribed rest in \(.applicationName)",
                "How long should I rest in \(.applicationName)",
                "Rest prescription in \(.applicationName)"
            ],
            shortTitle: "Prescribed Rest",
            systemImageName: "hourglass"
        )
    }
}
