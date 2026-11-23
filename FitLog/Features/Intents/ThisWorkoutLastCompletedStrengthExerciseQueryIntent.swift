//
//  ThisWorkoutLastCompletedStrengthExerciseQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which startable *strength* exercise was most
//  recently finished in this session, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Cardio completed
//  and placeholders do not count. Distinct from Azurite This
//  Workout Last Completed Exercise (any startable row, including
//  cardio), Tourmaline Current Exercise (focused row), Spinel
//  Previous Exercise (leftover neighbor), Alexandrite Remaining
//  Exercises, and Hematite This Workout Exercises Completed
//  (count).
//

import AppIntents
import Foundation

struct ThisWorkoutLastCompletedStrengthExerciseQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Completed Strength Exercise"
    static var description = IntentDescription(
        "Hear the name of the last finished strength exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = IoliteAskFitLog.thisWorkoutLastCompletedStrengthExerciseDialog(
            snapshot: FitLogIntentBridge.loadIoliteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
