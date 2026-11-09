//
//  RemainingExercisesQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which exercises are still left in the
//  in-progress workout without opening the app or logging anything
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Moonstone Ready to Finish (ready / not) and Jasper Sets Remaining
//  (prescribed set count).
//

import AppIntents
import Foundation

struct RemainingExercisesQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Remaining Exercises"
    static var description = IntentDescription(
        "Hear which exercises are still left in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AlexandriteAskFitLog.remainingExercisesDialog(
            snapshot: FitLogIntentBridge.loadAlexandriteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
