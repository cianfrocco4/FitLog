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
            intent: ResetRestTimeIntent(),
            phrases: [
                "Reset rest time in \(.applicationName)",
                "Restart rest in \(.applicationName)",
                "Reset the rest timer in \(.applicationName)"
            ],
            shortTitle: "Reset Rest Time",
            systemImageName: "arrow.counterclockwise"
        )

        AppShortcut(
            intent: PreviousExerciseTargetQueryIntent(),
            phrases: [
                "Previous exercise target in \(.applicationName)",
                "What's the target for the previous exercise in \(.applicationName)",
                "What was before this in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Target",
            systemImageName: "target"
        )

        AppShortcut(
            intent: ThisExerciseLastWorkingQueryIntent(),
            phrases: [
                "This exercise last working in \(.applicationName)",
                "What did I last lift on this exercise in \(.applicationName)",
                "Last working set on this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Last Working",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
