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
            intent: StartTodaysWorkoutIntent(),
            phrases: [
                "Start today's workout in \(.applicationName)",
                "Start today's plan in \(.applicationName)",
                "Do today's workout in \(.applicationName)"
            ],
            shortTitle: "Start Today's Workout",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: StartLastCardioIntent(),
            phrases: [
                "Start last cardio in \(.applicationName)",
                "Start my last cardio in \(.applicationName)",
                "Repeat last cardio in \(.applicationName)"
            ],
            shortTitle: "Start Last Cardio",
            systemImageName: "figure.run"
        )

        AppShortcut(
            intent: DidITrainTodayIntent(),
            phrases: [
                "Did I train today in \(.applicationName)",
                "Did I work out today in \(.applicationName)",
                "Have I trained today in \(.applicationName)"
            ],
            shortTitle: "Did I Train Today",
            systemImageName: "calendar.badge.checkmark"
        )
    }
}
