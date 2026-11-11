//
//  AddRestTimeIntent.swift
//  FitLog
//
//  Add 30 seconds to a live rest countdown via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  log a set, or invent rest when none is running (`like.rest.no_nag`).
//  Distinct from RestTimerIntent (starts rest) and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct AddRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Rest Time"
    static var description = IntentDescription(
        "Add 30 seconds to the live rest countdown in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadZirconSessionSnapshot()
        if ZirconAskFitLog.canAddRest(snapshot: snapshot) {
            FitLogIntentBridge.queueAddRestTime()
        }
        let message = ZirconAskFitLog.addRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
