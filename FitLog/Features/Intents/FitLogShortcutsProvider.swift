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
            intent: StartNextPlanWorkoutIntent(),
            phrases: [
                "Start next plan workout in \(.applicationName)",
                "Start my next planned workout in \(.applicationName)",
                "Start the next training day in \(.applicationName)"
            ],
            shortTitle: "Start Next Plan Workout",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: NextPlanWorkoutQueryIntent(),
            phrases: [
                "What's my next planned workout in \(.applicationName)",
                "Next planned workout in \(.applicationName)",
                "When is my next training day in \(.applicationName)"
            ],
            shortTitle: "Next Plan Workout",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: ThisWeeksPlanQueryIntent(),
            phrases: [
                "What's this week's plan in \(.applicationName)",
                "This week's plan in \(.applicationName)",
                "What am I training this week in \(.applicationName)"
            ],
            shortTitle: "This Week's Plan",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
