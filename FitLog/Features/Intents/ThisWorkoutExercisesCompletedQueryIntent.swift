//
//  ThisWorkoutExercisesCompletedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many startable exercises are already
//  done in the in-progress workout, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Placeholders do not
//  count. Distinct from Alexandrite Remaining Exercises (leftover
//  row count), Sunstone This Workout Remaining Sets (leftover working
//  sets), Tanzanite Sets Logged, and Jasper Sets Remaining.
//

import AppIntents
import Foundation

struct ThisWorkoutExercisesCompletedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Exercises Completed"
    static var description = IntentDescription(
        "Hear how many exercises are already done in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = HematiteAskFitLog.thisWorkoutExercisesCompletedDialog(
            snapshot: FitLogIntentBridge.loadHematiteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
