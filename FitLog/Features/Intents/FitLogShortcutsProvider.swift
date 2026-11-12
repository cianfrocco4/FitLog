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
            intent: SubtractRestTimeIntent(),
            phrases: [
                "Subtract rest time in \(.applicationName)",
                "Take 30 seconds off rest in \(.applicationName)",
                "Give me less rest in \(.applicationName)"
            ],
            shortTitle: "Subtract Rest Time",
            systemImageName: "minus.circle"
        )

        AppShortcut(
            intent: NextExerciseTargetQueryIntent(),
            phrases: [
                "Next exercise target in \(.applicationName)",
                "What's the target for the next exercise in \(.applicationName)",
                "What should I do next in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Target",
            systemImageName: "target"
        )

        AppShortcut(
            intent: NextExerciseLastWorkingQueryIntent(),
            phrases: [
                "Next exercise last working in \(.applicationName)",
                "What did I last lift on the next exercise in \(.applicationName)",
                "Last working set on next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise Last Working",
            systemImageName: "clock.arrow.circlepath"
        )
    }
}
