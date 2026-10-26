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
            intent: RepeatYesterdayIntent(),
            phrases: [
                "Repeat yesterday in \(.applicationName)",
                "Do yesterday's workout in \(.applicationName)",
                "Repeat last session in \(.applicationName)"
            ],
            shortTitle: "Repeat Yesterday",
            systemImageName: "arrow.counterclockwise"
        )

        AppShortcut(
            intent: ReadinessQueryIntent(),
            phrases: [
                "What's my readiness in \(.applicationName)",
                "Readiness score in \(.applicationName)"
            ],
            shortTitle: "Readiness",
            systemImageName: "heart.text.square"
        )

        AppShortcut(
            intent: TodayPlanQueryIntent(),
            phrases: [
                "What's today's workout in \(.applicationName)",
                "Today's plan in \(.applicationName)"
            ],
            shortTitle: "Today's Workout",
            systemImageName: "calendar"
        )
    }
}
