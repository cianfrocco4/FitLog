//
//  CurrentWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which workout is in progress and which
//  exercise is focused, without opening the app (`like.history.logged`
//  / `like.rest.no_nag`). Distinct from Peridot In-Progress Workout
//  (yes / no) and Tourmaline Current Exercise (exercise only).
//

import AppIntents
import Foundation

struct CurrentWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Current Workout"
    static var description = IntentDescription(
        "Hear the in-progress workout and focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AlexandriteAskFitLog.currentWorkoutDialog(
            snapshot: FitLogIntentBridge.loadAlexandriteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
