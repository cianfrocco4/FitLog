//
//  SubtractRestTimeIntent.swift
//  FitLog
//
//  Subtract 30 seconds from a live rest countdown via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  log a set, or invent rest when none is running (`like.rest.no_nag`).
//  Floors at 1 second so a short remaining rest is not treated as Skip
//  Rest. Distinct from RestTimerIntent (starts rest), Zircon Add Rest
//  Time, and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct SubtractRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Subtract Rest Time"
    static var description = IntentDescription(
        "Subtract 30 seconds from the live rest countdown in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadObsidianSessionSnapshot()
        if ObsidianAskFitLog.canSubtractRest(snapshot: snapshot) {
            FitLogIntentBridge.queueSubtractRestTime()
        }
        let message = ObsidianAskFitLog.subtractRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
