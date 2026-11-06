//
//  SkipRestIntent.swift
//  FitLog
//
//  End the in-progress rest countdown via Siri / Shortcuts without
//  opening the sheet. Complements Rest Timer (which starts rest).
//  Idle / expired rest is left alone (`like.rest.no_nag`).
//

import AppIntents
import Foundation

struct SkipRestIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip Rest"
    static var description = IntentDescription(
        "Skip the rest timer in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadAquamarineSessionSnapshot()
        let now = Date()
        if AquamarineAskFitLog.canSkipRest(snapshot: snapshot, now: now) {
            FitLogIntentBridge.queueSkipRest()
        }
        let message = AquamarineAskFitLog.skipRestDialog(snapshot: snapshot, now: now)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
