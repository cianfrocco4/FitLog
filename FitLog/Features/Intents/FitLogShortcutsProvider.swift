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
            intent: ResumeInProgressWorkoutIntent(),
            phrases: [
                "Resume workout in \(.applicationName)",
                "Continue my workout in \(.applicationName)",
                "Open my current workout in \(.applicationName)"
            ],
            shortTitle: "Resume Workout",
            systemImageName: "play.circle"
        )

        AppShortcut(
            intent: LastSessionExercisesQueryIntent(),
            phrases: [
                "Last session exercises in \(.applicationName)",
                "What did I lift last time in \(.applicationName)",
                "What exercises did I do last in \(.applicationName)"
            ],
            shortTitle: "Last Session Exercises",
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: DaysSinceLastWorkoutQueryIntent(),
            phrases: [
                "Days since last workout in \(.applicationName)",
                "When did I last train in \(.applicationName)",
                "How long since my last workout in \(.applicationName)"
            ],
            shortTitle: "Days Since Last Workout",
            systemImageName: "calendar"
        )
    }
}
