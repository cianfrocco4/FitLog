//
//  SkipRemainingSetsIntent.swift
//  FitLog
//
//  Mark the focused incomplete exercise done via Siri / Shortcuts so
//  remaining prescribed sets are not logged as fake work
//  (`like.history.logged`). Does not start a workout, finish one, or
//  invent a skip when there is no in-progress incomplete row
//  (`like.rest.no_nag`). Distinct from Jasper Next Exercise (query
//  only), Peridot Finish Workout, and Tanzanite Undo Last Set.
//

import AppIntents
import Foundation

struct SkipRemainingSetsIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Remaining Sets"
    static var description = IntentDescription(
        "Skip remaining sets on the current exercise in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadMoonstoneSessionSnapshot()
        if MoonstoneAskFitLog.canSkipRemaining(snapshot: snapshot) {
            FitLogIntentBridge.queueSkipRemainingSets()
        }
        let message = MoonstoneAskFitLog.skipRemainingDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
