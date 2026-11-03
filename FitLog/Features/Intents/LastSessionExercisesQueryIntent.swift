//
//  LastSessionExercisesQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which exercises were in the last History session
//  and speak last working load (skips warm-ups) or last cardio duration
//  (`improve.home.last_weight` / `like.history.logged` /
//  `improve.cardio.home_duration`). Distinct from Peridot Last Finished
//  (name + one caption) and Citrine last-workout queries.
//

import AppIntents
import Foundation

struct LastSessionExercisesQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Session Exercises"
    static var description = IntentDescription(
        "Hear the exercises from the last workout saved to History in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = LapisAskFitLog.lastSessionExercisesDialog(
            snapshot: FitLogIntentBridge.loadLapisHistorySnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
