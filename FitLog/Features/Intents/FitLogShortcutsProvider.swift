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
            intent: UseLastRestTimeIntent(),
            phrases: [
                "Use last rest time in \(.applicationName)",
                "Set rest to last rest in \(.applicationName)",
                "Use my last rest in \(.applicationName)"
            ],
            shortTitle: "Use Last Rest Time",
            systemImageName: "clock.arrow.circlepath"
        )

        AppShortcut(
            intent: PreviousExerciseRemainingSetsQueryIntent(),
            phrases: [
                "Previous exercise remaining sets in \(.applicationName)",
                "How many sets left on the previous exercise in \(.applicationName)",
                "Sets left on the previous exercise in \(.applicationName)"
            ],
            shortTitle: "Previous Exercise Remaining Sets",
            systemImageName: "list.number"
        )

        AppShortcut(
            intent: NextExerciseLastRestQueryIntent(),
            phrases: [
                "Next exercise last rest in \(.applicationName)",
                "How long did I rest on the next exercise in \(.applicationName)",
                "Last rest on the next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Last Rest",
            systemImageName: "timer"
        )
    }
}
