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
            intent: UseThisWorkoutLastWarmupRestTimeIntent(),
            phrases: [
                "Use this workout last warmup rest in \(.applicationName)",
                "Set rest to this workout last warmup rest in \(.applicationName)",
                "Use last warmup rest in \(.applicationName)"
            ],
            shortTitle: "Use This Workout Last Warmup Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisWorkoutLastWarmupRestQueryIntent(),
            phrases: [
                "This workout last warmup rest in \(.applicationName)",
                "What was last warmup rest this workout in \(.applicationName)",
                "Last warmup rest this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Warmup Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ThisWorkoutWarmupSetsLoggedQueryIntent(),
            phrases: [
                "This workout warmup sets logged in \(.applicationName)",
                "How many warmup sets this workout in \(.applicationName)",
                "Warmup sets logged this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Warmup Sets Logged",
            systemImageName: "checkmark.circle"
        )
    }
}
