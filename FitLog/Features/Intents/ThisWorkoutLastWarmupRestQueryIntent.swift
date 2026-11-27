//
//  ThisWorkoutLastWarmupRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged warm-up
//  rest in this session lasted, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Working sets,
//  cardio, and zero-second rest do not invent a duration. Distinct
//  from Iolite This Workout Last Working Rest, Sunstone Use This
//  Workout Last Rest Time (action / any last rest including
//  working), Coral Use Last Rest Time (focused, including
//  warm-ups), Hematite This Exercise Last Rest, and Azurite This
//  Workout Last Prescribed Rest action.
//

import AppIntents
import Foundation

struct ThisWorkoutLastWarmupRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Warmup Rest"
    static var description = IntentDescription(
        "Hear the last warm-up rest in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = KunziteAskFitLog.thisWorkoutLastWarmupRestDialog(
            snapshot: FitLogIntentBridge.loadKunziteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
