//
//  ReadyToFinishQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts whether the in-progress workout has its
//  prescribed work in, without finishing or opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from 999e
//  (in-app finish-ready banner) and Peridot Finish Workout (queues
//  finish).
//

import AppIntents
import Foundation

struct ReadyToFinishQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Ready to Finish"
    static var description = IntentDescription(
        "Hear whether the in-progress workout is ready to finish in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = MoonstoneAskFitLog.readyToFinishDialog(
            snapshot: FitLogIntentBridge.loadMoonstoneSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
