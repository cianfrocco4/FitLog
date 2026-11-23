//
//  ThisWorkoutLastWorkingRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged working-set
//  rest in this session lasted, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Warm-ups, cardio,
//  and zero-second rest do not invent a duration. Distinct from
//  Sunstone Use This Workout Last Rest Time (action / any last
//  rest including warm-ups), Coral Use Last Rest Time (focused),
//  Hematite This Exercise Last Rest, and Azurite This Workout Last
//  Prescribed Rest action.
//

import AppIntents
import Foundation

struct ThisWorkoutLastWorkingRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Working Rest"
    static var description = IntentDescription(
        "Hear the last working-set rest in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = IoliteAskFitLog.thisWorkoutLastWorkingRestDialog(
            snapshot: FitLogIntentBridge.loadIoliteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
