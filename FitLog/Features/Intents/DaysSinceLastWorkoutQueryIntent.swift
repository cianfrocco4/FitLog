//
//  DaysSinceLastWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long it has been since the last finished
//  workout (`like.rest.no_nag` / `improve.home.already_trained`) without
//  opening the app or starting a session. Distinct from Sapphire Did I
//  Train Today (yes/no today) and Peridot Last Finished (name only).
//

import AppIntents
import Foundation

struct DaysSinceLastWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Days Since Last Workout"
    static var description = IntentDescription(
        "Hear how many days it has been since the last workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = LapisAskFitLog.daysSinceLastWorkoutDialog(
            snapshot: FitLogIntentBridge.loadLapisHistorySnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
