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
            intent: SkipRemainingSetsIntent(),
            phrases: [
                "Skip remaining sets in \(.applicationName)",
                "Skip this exercise in \(.applicationName)",
                "Mark exercise done in \(.applicationName)"
            ],
            shortTitle: "Skip Remaining",
            systemImageName: "forward.end"
        )

        AppShortcut(
            intent: NextSetQueryIntent(),
            phrases: [
                "Next set in \(.applicationName)",
                "What's my next set in \(.applicationName)",
                "Which set am I on in \(.applicationName)"
            ],
            shortTitle: "Next Set",
            systemImageName: "list.number"
        )

        AppShortcut(
            intent: ReadyToFinishQueryIntent(),
            phrases: [
                "Ready to finish in \(.applicationName)",
                "Am I ready to finish in \(.applicationName)",
                "Are all sets logged in \(.applicationName)"
            ],
            shortTitle: "Ready to Finish",
            systemImageName: "flag.checkered"
        )
    }
}
