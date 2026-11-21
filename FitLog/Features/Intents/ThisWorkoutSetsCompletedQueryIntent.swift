//
//  ThisWorkoutSetsCompletedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets are already logged in
//  the in-progress workout, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Warm-ups, timed
//  holds, interval rests, placeholders, and zero-second cardio do
//  not count; cardio work with duration counts as one set each.
//  Distinct from Hematite This Workout Exercises Completed (row
//  count), Sunstone This Workout Remaining Sets, Tanzanite Sets
//  Logged, Jasper Sets Remaining, Jade This Exercise Remaining
//  Sets, and Spinel This Exercise Sets.
//

import AppIntents
import Foundation

struct ThisWorkoutSetsCompletedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Sets Completed"
    static var description = IntentDescription(
        "Hear how many working sets are already done in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = MalachiteAskFitLog.thisWorkoutSetsCompletedDialog(
            snapshot: FitLogIntentBridge.loadMalachiteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
