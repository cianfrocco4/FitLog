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
            intent: DoubleRestTimeIntent(),
            phrases: [
                "Double rest time in \(.applicationName)",
                "Double the rest timer in \(.applicationName)",
                "Give me double rest in \(.applicationName)"
            ],
            shortTitle: "Double Rest Time",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: NextExerciseRemainingSetsQueryIntent(),
            phrases: [
                "Next exercise remaining sets in \(.applicationName)",
                "How many sets left on the next exercise in \(.applicationName)",
                "Sets left on the next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Remaining Sets",
            systemImageName: "list.number"
        )

        AppShortcut(
            intent: ThisExerciseLastRestQueryIntent(),
            phrases: [
                "This exercise last rest in \(.applicationName)",
                "How long did I rest on this exercise in \(.applicationName)",
                "Last rest on this exercise in \(.applicationName)"
            ],
            shortTitle: "This Exercise Last Rest",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
