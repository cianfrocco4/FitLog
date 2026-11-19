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
            intent: UseThisWorkoutLastRestTimeIntent(),
            phrases: [
                "Use this workout last rest time in \(.applicationName)",
                "Set rest to last rest this workout in \(.applicationName)",
                "Use last rest this workout in \(.applicationName)"
            ],
            shortTitle: "Use This Workout Last Rest Time",
            systemImageName: "arrow.uturn.backward"
        )

        AppShortcut(
            intent: ThisWorkoutRemainingSetsQueryIntent(),
            phrases: [
                "This workout remaining sets in \(.applicationName)",
                "How many sets left this workout in \(.applicationName)",
                "Sets left this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Remaining Sets",
            systemImageName: "square.stack"
        )

        AppShortcut(
            intent: ThisWorkoutLastWorkingQueryIntent(),
            phrases: [
                "This workout last working in \(.applicationName)",
                "What did I last lift this workout in \(.applicationName)",
                "Last working set this workout in \(.applicationName)"
            ],
            shortTitle: "This Workout Last Working",
            systemImageName: "dumbbell"
        )
    }
}
