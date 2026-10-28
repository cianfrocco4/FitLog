//
//  LastStrengthQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts for last working load from the newest strength
//  session (`improve.home.last_weight`) without opening the app. Distinct
//  from Citrine Last Weight (optional exercise name) and Last Workout
//  (any last session, including cardio).
//

import AppIntents
import Foundation

struct LastStrengthQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Strength"
    static var description = IntentDescription(
        "Hear your last strength workout and working load in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = EmeraldAskFitLog.lastStrengthLoadDialog(
            snapshot: FitLogIntentBridge.loadEmeraldStrengthSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
