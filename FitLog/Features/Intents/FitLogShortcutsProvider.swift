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
            intent: RepeatLastSetIntent(),
            phrases: [
                "Repeat last set in \(.applicationName)",
                "Log that set again in \(.applicationName)",
                "Same set again in \(.applicationName)"
            ],
            shortTitle: "Repeat Last Set",
            systemImageName: "repeat"
        )

        AppShortcut(
            intent: SetsRemainingQueryIntent(),
            phrases: [
                "Sets remaining in \(.applicationName)",
                "How many sets left in \(.applicationName)",
                "What's left in my workout in \(.applicationName)"
            ],
            shortTitle: "Sets Remaining",
            systemImageName: "number"
        )

        AppShortcut(
            intent: NextExerciseQueryIntent(),
            phrases: [
                "Next exercise in \(.applicationName)",
                "What's next in my workout in \(.applicationName)",
                "What exercise is next in \(.applicationName)"
            ],
            shortTitle: "Next Exercise",
            systemImageName: "arrow.right.circle"
        )
    }
}
