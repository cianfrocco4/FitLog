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
            intent: UseLastWeightIntent(),
            phrases: [
                "Use last weight in \(.applicationName)",
                "Log last weight in \(.applicationName)",
                "Reuse last working weight in \(.applicationName)"
            ],
            shortTitle: "Last Weight",
            systemImageName: "scalemass"
        )

        AppShortcut(
            intent: SkipRestIntent(),
            phrases: [
                "Skip rest in \(.applicationName)",
                "Skip rest timer in \(.applicationName)",
                "End rest in \(.applicationName)"
            ],
            shortTitle: "Skip Rest",
            systemImageName: "forward.end"
        )

        AppShortcut(
            intent: RestRemainingQueryIntent(),
            phrases: [
                "Rest remaining in \(.applicationName)",
                "How much rest is left in \(.applicationName)",
                "What's my rest time in \(.applicationName)"
            ],
            shortTitle: "Rest Remaining",
            systemImageName: "hourglass"
        )
    }
}
