//
//  InProgressWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts whether a workout is still in progress
//  (`like.history.logged`) without opening the app. Distinct from
//  Sapphire Did I Train Today (completed vs rest) and Ruby Repeat
//  Yesterday.
//

import AppIntents
import Foundation

struct InProgressWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "In-Progress Workout"
    static var description = IntentDescription(
        "Hear whether a workout is still in progress in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = PeridotAskFitLog.inProgressWorkoutDialog(
            snapshot: FitLogIntentBridge.loadPeridotFinishSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
