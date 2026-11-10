//
//  PreviousExerciseQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which incomplete exercise sits before the
//  focused one, without opening the app or changing focus
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Alexandrite Remaining Exercises (what's left) and Jasper Next
//  Exercise (query only, next incomplete).
//

import AppIntents
import Foundation

struct PreviousExerciseQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise"
    static var description = IntentDescription(
        "Hear the previous incomplete exercise in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = SpinelAskFitLog.previousExerciseDialog(
            snapshot: FitLogIntentBridge.loadSpinelSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
