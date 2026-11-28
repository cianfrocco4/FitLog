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
            intent: UseThisExerciseLastWarmupRestTimeIntent(),
            phrases: [
                "Use this exercise last warmup rest in \(.applicationName)",
                "Set rest to this exercise last warmup rest in \(.applicationName)",
                "Use this lift last warmup rest in \(.applicationName)"
            ],
            shortTitle: "Use This Exercise Last Warmup Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisExerciseLastWarmupRestQueryIntent(),
            phrases: [
                "This exercise last warmup rest in \(.applicationName)",
                "What was last warmup rest this exercise in \(.applicationName)",
                "Last warmup rest this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Last Warmup Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ThisExerciseWarmupSetsLoggedQueryIntent(),
            phrases: [
                "This exercise warmup sets logged in \(.applicationName)",
                "How many warmup sets this exercise in \(.applicationName)",
                "Warmup sets logged this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Warmup Sets Logged",
            systemImageName: "checkmark.circle"
        )
    }
}
