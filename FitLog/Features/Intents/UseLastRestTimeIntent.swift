//
//  UseLastRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the focused exercise's last logged rest
//  via Siri / Shortcuts (`like.history.logged`). Does not start a rest
//  timer, skip rest, add/subtract 30 seconds, reset to prescribed, double
//  or halve rest, log a set, or invent rest when none is running
//  (`like.rest.no_nag`). Distinct from RestTimerIntent (starts rest),
//  Amber Double Rest Time, Jade Halve Rest Time, Zircon Add Rest Time,
//  Obsidian Subtract Rest Time, Fluorite Reset Rest Time, and
//  Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct UseLastRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Last Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the last rest logged on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadCoralSessionSnapshot()
        if CoralAskFitLog.canUseLastRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseLastRestTime()
        }
        let message = CoralAskFitLog.useLastRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
