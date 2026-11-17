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
            intent: UsePreviousLastRestTimeIntent(),
            phrases: [
                "Use previous last rest time in \(.applicationName)",
                "Set rest to previous last rest in \(.applicationName)",
                "Use the previous exercise rest in \(.applicationName)"
            ],
            shortTitle: "Use Previous Last Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: PreviousExerciseLastRestQueryIntent(),
            phrases: [
                "Previous exercise last rest in \(.applicationName)",
                "How long did I rest on the previous exercise in \(.applicationName)",
                "Last rest on the previous exercise in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Last Rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: NextExercisePrescribedRestQueryIntent(),
            phrases: [
                "Next exercise prescribed rest in \(.applicationName)",
                "How long should I rest on the next exercise in \(.applicationName)",
                "Prescribed rest on the next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Prescribed Rest",
            systemImageName: "hourglass"
        )
    }
}
