//
//  TomorrowsWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts what is assigned tomorrow (`like.plan.today` /
//  `like.rest.no_nag`) without opening the app. Distinct from Ruby
//  Today's Workout query and Sapphire Start Today's Workout.
//

import AppIntents
import Foundation

struct TomorrowsWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Tomorrow's Workout"
    static var description = IntentDescription(
        "Hear tomorrow's planned workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AmethystAskFitLog.tomorrowsWorkoutDialog(
            snapshot: FitLogIntentBridge.loadAmethystTomorrowSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
