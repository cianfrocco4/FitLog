//
//  ThisExerciseSetsQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets are logged on the
//  focused exercise, without opening the app or logging anything
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Tanzanite Sets Logged (session-wide), Jasper Sets Remaining
//  (prescribed leftover), and Moonstone Next Set (next unlogged
//  working set number).
//

import AppIntents
import Foundation

struct ThisExerciseSetsQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Sets"
    static var description = IntentDescription(
        "Hear working sets logged on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = SpinelAskFitLog.thisExerciseSetsDialog(
            snapshot: FitLogIntentBridge.loadSpinelSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
