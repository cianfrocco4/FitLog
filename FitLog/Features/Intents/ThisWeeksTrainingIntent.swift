//
//  ThisWeeksTrainingIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many sessions were logged this calendar week
//  (`like.history.logged` / `improve.home.already_trained`) without
//  opening the app. Distinct from Did I Train Today (same-day only).
//

import AppIntents
import Foundation

struct ThisWeeksTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "This Week's Training"
    static var description = IntentDescription(
        "Hear how many workouts you logged this week in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = EmeraldAskFitLog.thisWeeksTrainingDialog(
            snapshot: FitLogIntentBridge.loadEmeraldStrengthSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
