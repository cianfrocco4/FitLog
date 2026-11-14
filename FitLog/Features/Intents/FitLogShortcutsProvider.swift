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
            intent: HalveRestTimeIntent(),
            phrases: [
                "Halve rest time in \(.applicationName)",
                "Cut rest in half in \(.applicationName)",
                "Halve the rest timer in \(.applicationName)"
            ],
            shortTitle: "Halve Rest Time",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: PreviousExerciseLastWorkingQueryIntent(),
            phrases: [
                "Previous exercise last working in \(.applicationName)",
                "What did I last lift on the previous exercise in \(.applicationName)",
                "Last working set on the previous exercise in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Last Working",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: ThisExerciseRemainingSetsQueryIntent(),
            phrases: [
                "This exercise remaining sets in \(.applicationName)",
                "How many sets left on this exercise in \(.applicationName)",
                "Sets left on this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Remaining Sets",
            systemImageName: "list.number"
        )
    }
}
