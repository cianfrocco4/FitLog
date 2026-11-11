//
//  PrescribedRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long to rest on the focused exercise,
//  without opening the app or changing the live countdown
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Aquamarine Rest Remaining (time left on the live timer) and
//  RestTimerIntent (starts rest).
//

import AppIntents
import Foundation

struct PrescribedRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Prescribed Rest"
    static var description = IntentDescription(
        "Hear the prescribed rest on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = ZirconAskFitLog.prescribedRestDialog(
            snapshot: FitLogIntentBridge.loadZirconSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
