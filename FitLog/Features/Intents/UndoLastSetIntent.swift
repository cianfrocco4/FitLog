//
//  UndoLastSetIntent.swift
//  FitLog
//
//  Remove the most recently logged real set via Siri / Shortcuts so a
//  logging mistake does not require opening the sheet
//  (`like.history.logged`). Does not start a workout, finish one, or
//  invent an undo when there is no in-progress session or no real set
//  (`like.rest.no_nag`). Distinct from Jasper Repeat Last Set (copies
//  a this-session working set) and Log Set (requires weight/reps).
//

import AppIntents
import Foundation

struct UndoLastSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Set"
    static var description = IntentDescription(
        "Undo the last logged set in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadTanzaniteSessionSnapshot()
        if TanzaniteAskFitLog.canUndoLastSet(snapshot: snapshot) {
            FitLogIntentBridge.queueUndoLastSet()
        }
        let message = TanzaniteAskFitLog.undoLastSetDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
