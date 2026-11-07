//
//  SetsLoggedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many sets are already logged in the
//  in-progress workout without opening the app or logging anything
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from Jasper
//  Sets Remaining (prescribed work still left).
//

import AppIntents
import Foundation

struct SetsLoggedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Sets Logged"
    static var description = IntentDescription(
        "Hear how many sets are logged in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = TanzaniteAskFitLog.setsLoggedDialog(
            snapshot: FitLogIntentBridge.loadTanzaniteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
