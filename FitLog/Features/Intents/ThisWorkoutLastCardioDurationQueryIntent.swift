//
//  ThisWorkoutLastCardioDurationQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged cardio
//  work in this session lasted, without opening the app
//  (`like.history.logged` / `like.rest.no_nag` /
//  `improve.cardio.home_duration`). Zero-second cardio and
//  interval rests do not invent a duration. Distinct from
//  Tourmaline Use Last Cardio Duration (action that applies
//  duration to the focused cardio row) and Last Set query.
//

import AppIntents
import Foundation

struct ThisWorkoutLastCardioDurationQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Cardio Duration"
    static var description = IntentDescription(
        "Hear the last logged cardio duration in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AzuriteAskFitLog.thisWorkoutLastCardioDurationDialog(
            snapshot: FitLogIntentBridge.loadAzuriteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
