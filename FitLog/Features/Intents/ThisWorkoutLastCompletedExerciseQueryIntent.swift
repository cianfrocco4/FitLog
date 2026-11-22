//
//  ThisWorkoutLastCompletedExerciseQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which startable exercise was most recently
//  finished in this session, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Placeholders do
//  not count. Distinct from Tourmaline Current Exercise (focused
//  row), Spinel Previous Exercise (leftover neighbor), Alexandrite
//  Next Exercise / Remaining Exercises, and Hematite This Workout
//  Exercises Completed (count).
//

import AppIntents
import Foundation

struct ThisWorkoutLastCompletedExerciseQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Completed Exercise"
    static var description = IntentDescription(
        "Hear the name of the last finished exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AzuriteAskFitLog.thisWorkoutLastCompletedExerciseDialog(
            snapshot: FitLogIntentBridge.loadAzuriteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
