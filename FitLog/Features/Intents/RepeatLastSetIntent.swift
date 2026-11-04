//
//  RepeatLastSetIntent.swift
//  FitLog
//
//  Log the last working set again via Siri / Shortcuts so the next
//  working set does not require typing weight/reps
//  (`improve.history.quick_log` / `improve.home.last_weight`).
//  Does not start a workout, finish one, or invent a set when nothing
//  working is logged (`like.rest.no_nag`). Distinct from Log Set
//  (requires weight/reps) and Lapis Resume (opens the sheet only).
//

import AppIntents
import Foundation

struct RepeatLastSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Repeat Last Set"
    static var description = IntentDescription(
        "Log the last working set again in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadJasperSessionSnapshot()
        if JasperAskFitLog.canRepeatLastSet(snapshot: snapshot) {
            FitLogIntentBridge.queueRepeatLastSet()
        }
        let message = JasperAskFitLog.repeatLastSetDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
