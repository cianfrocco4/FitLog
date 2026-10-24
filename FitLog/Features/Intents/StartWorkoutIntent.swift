//
//  StartWorkoutIntent.swift
//  FitLog
//
//  Start a workout via Siri or Shortcuts (Task 30).
//

import Foundation
import AppIntents

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Begin a saved workout in Workout Log AI. With no name, starts your last workout.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Workout Name", description: "Optional workout template name")
    var workoutName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadLastSavedWorkout()
        guard let resolved = TopazLastWorkingLoad.resolvedStartWorkoutName(
            requested: workoutName,
            snapshot: snapshot
        ) else {
            return .result(dialog: IntentDialog(stringLiteral: TopazLastWorkingLoad.noSavedWorkoutDialog))
        }

        FitLogIntentBridge.queueStartWorkout(named: resolved)
        return .result(
            dialog: IntentDialog(
                stringLiteral: TopazLastWorkingLoad.startDialog(
                    workoutName: resolved,
                    lastLoadCaption: TopazLastWorkingLoad.startLastLoadCaption(
                        requested: workoutName,
                        snapshot: snapshot
                    )
                )
            )
        )
    }
}
