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
            intent: StartLastStrengthIntent(),
            phrases: [
                "Start last strength in \(.applicationName)",
                "Start my last strength workout in \(.applicationName)",
                "Repeat last strength in \(.applicationName)"
            ],
            shortTitle: "Start Last Strength",
            systemImageName: "dumbbell"
        )

        AppShortcut(
            intent: LastStrengthQueryIntent(),
            phrases: [
                "Last strength in \(.applicationName)",
                "What was my last strength in \(.applicationName)",
                "Last working set in \(.applicationName)"
            ],
            shortTitle: "Last Strength",
            systemImageName: "scalemass"
        )

        AppShortcut(
            intent: ThisWeeksTrainingIntent(),
            phrases: [
                "This week's training in \(.applicationName)",
                "How many workouts this week in \(.applicationName)",
                "Workouts this week in \(.applicationName)"
            ],
            shortTitle: "This Week's Training",
            systemImageName: "calendar.badge.clock"
        )
    }
}
