//
//  RestRemainingQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how much rest is left without opening the
//  app or starting a timer (`like.rest.no_nag`). Distinct from Rest
//  Timer (starts rest) and Skip Rest (ends rest).
//

import AppIntents
import Foundation

struct RestRemainingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Rest Remaining"
    static var description = IntentDescription(
        "Hear how much rest is left in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AquamarineAskFitLog.restRemainingDialog(
            snapshot: FitLogIntentBridge.loadAquamarineSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
