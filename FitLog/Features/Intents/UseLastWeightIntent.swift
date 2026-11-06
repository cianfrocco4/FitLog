//
//  UseLastWeightIntent.swift
//  FitLog
//
//  Log the last History working weight onto the unfinished strength
//  row via Siri / Shortcuts so the first working set does not require
//  opening History (`improve.home.last_weight` / `like.history.logged`).
//  Does not start a workout, finish one, or invent a set when there
//  is no unfinished strength row or no previous working load
//  (`like.rest.no_nag`). Distinct from Jasper Repeat Last Set
//  (this-session working sets) and Tourmaline Use Last Cardio Duration.
//

import AppIntents
import Foundation

struct UseLastWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Last Weight"
    static var description = IntentDescription(
        "Log the last working weight onto the unfinished strength exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadAquamarineSessionSnapshot()
        if AquamarineAskFitLog.canApplyLastWeight(snapshot: snapshot) {
            FitLogIntentBridge.queueUseLastWeight()
        }
        let message = AquamarineAskFitLog.useLastWeightDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
