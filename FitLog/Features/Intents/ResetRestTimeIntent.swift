//
//  ResetRestTimeIntent.swift
//  FitLog
//
//  Reset a live rest countdown to the focused row's prescribed rest
//  via Siri / Shortcuts (`like.history.logged`). Does not start a rest
//  timer, skip rest, add/subtract 30 seconds, log a set, or invent rest
//  when none is running (`like.rest.no_nag`). Distinct from
//  RestTimerIntent (starts rest), Zircon Add Rest Time, Obsidian
//  Subtract Rest Time, and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct ResetRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Rest Time"
    static var description = IntentDescription(
        "Reset the live rest countdown to the prescribed rest in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadFluoriteSessionSnapshot()
        if FluoriteAskFitLog.canResetRest(snapshot: snapshot) {
            FitLogIntentBridge.queueResetRestTime()
        }
        let message = FluoriteAskFitLog.resetRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
