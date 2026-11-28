//
//  ThisExerciseLastWarmupRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged warm-up
//  rest on the focused exercise lasted, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Working sets,
//  cardio, other exercises, and zero-second rest do not invent a
//  duration. Distinct from Kunzite This Workout Last Warmup Rest
//  (any exercise), Kyanite This Exercise Last Working Rest, Coral
//  Use Last Rest Time (focused last rest including working),
//  Hematite This Exercise Last Rest (any rest including working),
//  and Iolite This Workout Last Working Rest.
//

import AppIntents
import Foundation

struct ThisExerciseLastWarmupRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Last Warmup Rest"
    static var description = IntentDescription(
        "Hear the last warm-up rest on the focused exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = HiddeniteAskFitLog.thisExerciseLastWarmupRestDialog(
            snapshot: FitLogIntentBridge.loadHiddeniteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
