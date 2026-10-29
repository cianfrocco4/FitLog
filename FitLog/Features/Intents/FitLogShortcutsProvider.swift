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
            intent: StartTomorrowsWorkoutIntent(),
            phrases: [
                "Start tomorrow's workout in \(.applicationName)",
                "Start tomorrow's plan in \(.applicationName)",
                "Do tomorrow's workout in \(.applicationName)"
            ],
            shortTitle: "Start Tomorrow's Workout",
            systemImageName: "calendar.badge.plus"
        )

        AppShortcut(
            intent: TomorrowsWorkoutQueryIntent(),
            phrases: [
                "What's tomorrow's workout in \(.applicationName)",
                "Tomorrow's plan in \(.applicationName)",
                "What am I training tomorrow in \(.applicationName)"
            ],
            shortTitle: "Tomorrow's Workout",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: LastSessionDurationIntent(),
            phrases: [
                "How long was my last session in \(.applicationName)",
                "Last session duration in \(.applicationName)",
                "How long did I train last in \(.applicationName)"
            ],
            shortTitle: "Last Session Duration",
            systemImageName: "stopwatch"
        )
    }
}
