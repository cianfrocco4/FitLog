//
//  LastWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts what the last completed workout was, including last
//  working load or last cardio duration. Read-only — does not start a session.
//

import AppIntents
import Foundation

struct LastWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Workout"
    static var description = IntentDescription(
        "Hear your last completed workout and last working load in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadLastLoadQuerySnapshot()
        let message = CitrineLastWorkingLoad.lastWorkoutDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
