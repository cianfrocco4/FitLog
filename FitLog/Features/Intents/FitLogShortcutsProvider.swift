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
            intent: UseNextExerciseLastWorkingRestTimeIntent(),
            phrases: [
                "Use next exercise last working rest in \(.applicationName)",
                "Set rest to next exercise last working rest in \(.applicationName)",
                "Use next lift last working rest in \(.applicationName)"
            ],
            shortTitle: "Use Next Exercise Last Working Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: NextExerciseLastWorkingRestQueryIntent(),
            phrases: [
                "Next exercise last working rest in \(.applicationName)",
                "What was last working rest next exercise in \(.applicationName)",
                "Last working rest next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Last Working Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: NextExerciseWorkingSetsLoggedQueryIntent(),
            phrases: [
                "Next exercise working sets logged in \(.applicationName)",
                "How many working sets next exercise in \(.applicationName)",
                "Working sets logged next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Working Sets Logged",
            systemImageName: "checkmark.circle"
        )
    }
}
