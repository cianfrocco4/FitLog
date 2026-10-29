//
//  LastSessionDurationIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the last completed session lasted
//  (`like.history.logged`) without opening the app. Distinct from
//  Citrine Last Workout (name + last load) and Emerald This Week's
//  Training (session count).
//

import AppIntents
import Foundation

struct LastSessionDurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Session Duration"
    static var description = IntentDescription(
        "Hear how long your last workout lasted in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AmethystAskFitLog.lastSessionDurationDialog(
            snapshot: FitLogIntentBridge.loadAmethystTomorrowSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
