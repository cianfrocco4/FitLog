//
//  NextSetQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which set is next on the focused incomplete
//  exercise without opening the app or logging anything
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from Jasper
//  Sets Remaining (prescribed work still left across the session) and
//  Tourmaline Last Set (already logged).
//

import AppIntents
import Foundation

struct NextSetQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Set"
    static var description = IntentDescription(
        "Hear the next set on the current exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = MoonstoneAskFitLog.nextSetDialog(
            snapshot: FitLogIntentBridge.loadMoonstoneSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
