//
//  DoubleRestTimeIntent.swift
//  FitLog
//
//  Double a live rest countdown via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  add/subtract 30 seconds, reset to prescribed, halve rest, log a set,
//  or invent rest when none is running (`like.rest.no_nag`). Distinct from
//  RestTimerIntent (starts rest), Jade Halve Rest Time, Zircon Add Rest
//  Time, Obsidian Subtract Rest Time, Fluorite Reset Rest Time, and
//  Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct DoubleRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Double Rest Time"
    static var description = IntentDescription(
        "Double the live rest countdown in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadAmberSessionSnapshot()
        if AmberAskFitLog.canDoubleRest(snapshot: snapshot) {
            FitLogIntentBridge.queueDoubleRestTime()
        }
        let message = AmberAskFitLog.doubleRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
