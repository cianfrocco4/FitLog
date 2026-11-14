//
//  HalveRestTimeIntent.swift
//  FitLog
//
//  Halve a live rest countdown via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  add/subtract 30 seconds, reset to prescribed, log a set, or invent
//  rest when none is running (`like.rest.no_nag`). Distinct from
//  RestTimerIntent (starts rest), Zircon Add Rest Time, Obsidian
//  Subtract Rest Time, Fluorite Reset Rest Time, and Aquamarine Skip
//  Rest.
//

import AppIntents
import Foundation

struct HalveRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Halve Rest Time"
    static var description = IntentDescription(
        "Cut the live rest countdown in half in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadJadeSessionSnapshot()
        if JadeAskFitLog.canHalveRest(snapshot: snapshot) {
            FitLogIntentBridge.queueHalveRestTime()
        }
        let message = JadeAskFitLog.halveRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
