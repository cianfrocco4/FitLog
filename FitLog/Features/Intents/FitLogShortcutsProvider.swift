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
            intent: UseLastCardioDurationIntent(),
            phrases: [
                "Use last cardio duration in \(.applicationName)",
                "Log last cardio time in \(.applicationName)",
                "Repeat last cardio duration in \(.applicationName)"
            ],
            shortTitle: "Last Cardio Duration",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: LastSetQueryIntent(),
            phrases: [
                "Last set in \(.applicationName)",
                "What was my last set in \(.applicationName)",
                "What did I just log in \(.applicationName)"
            ],
            shortTitle: "Last Set",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: CurrentExerciseQueryIntent(),
            phrases: [
                "Current exercise in \(.applicationName)",
                "What exercise am I on in \(.applicationName)",
                "What's my current exercise in \(.applicationName)"
            ],
            shortTitle: "Current Exercise",
            systemImageName: "target"
        )
    }
}
