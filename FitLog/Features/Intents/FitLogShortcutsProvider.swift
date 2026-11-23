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
            intent: UseThisWorkoutLastWorkingRestTimeIntent(),
            phrases: [
                "Use this workout last working rest in \(.applicationName)",
                "Set rest to last working rest in \(.applicationName)",
                "Use last working set rest in \(.applicationName)"
            ],
            shortTitle: "Use This Workout Last Working Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisWorkoutLastWorkingRestQueryIntent(),
            phrases: [
                "This workout last working rest in \(.applicationName)",
                "What was last working rest this workout in \(.applicationName)",
                "Last working rest this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Working Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: ThisWorkoutLastCompletedStrengthExerciseQueryIntent(),
            phrases: [
                "This workout last completed strength exercise in \(.applicationName)",
                "Which strength exercise did I just finish in \(.applicationName)",
                "Last finished strength this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Completed Strength Exercise",
            systemImageName: "checkmark.circle"
        )
    }
}
