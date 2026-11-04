//
//  SetsRemainingQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many prescribed sets are left in the
//  in-progress workout (`like.history.logged`) without opening the
//  app or starting a session. Distinct from Peridot In-Progress
//  (name + set count already logged) and 999e finish-ready banner.
//

import AppIntents
import Foundation

struct SetsRemainingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Sets Remaining"
    static var description = IntentDescription(
        "Hear how many prescribed sets are left in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = JasperAskFitLog.setsRemainingDialog(
            snapshot: FitLogIntentBridge.loadJasperSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
