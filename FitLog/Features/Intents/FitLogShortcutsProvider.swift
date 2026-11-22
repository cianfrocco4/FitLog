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
            intent: UseThisWorkoutLastPrescribedRestTimeIntent(),
            phrases: [
                "Use this workout last prescribed rest in \(.applicationName)",
                "Set rest to last prescribed rest in \(.applicationName)",
                "Use last finished exercise rest prescription in \(.applicationName)"
            ],
            shortTitle: "Use This Workout Last Prescribed Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisWorkoutLastCardioDurationQueryIntent(),
            phrases: [
                "This workout last cardio duration in \(.applicationName)",
                "What was last cardio duration this workout in \(.applicationName)",
                "Last cardio this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Cardio Duration",
            systemImageName: "figure.run"
        )

        AppShortcut(
            intent: ThisWorkoutLastCompletedExerciseQueryIntent(),
            phrases: [
                "This workout last completed exercise in \(.applicationName)",
                "Which exercise did I just finish in \(.applicationName)",
                "Last finished exercise this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Completed Exercise",
            systemImageName: "checkmark.circle"
        )
    }
}
