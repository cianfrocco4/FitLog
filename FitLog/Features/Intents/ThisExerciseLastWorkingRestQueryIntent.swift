//
//  ThisExerciseLastWorkingRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged
//  working-set rest on the focused exercise lasted, without
//  opening the app (`like.history.logged` / `like.rest.no_nag`).
//  Warm-ups, cardio, other exercises, and zero-second rest do not
//  invent a duration. Distinct from Iolite This Workout Last
//  Working Rest (any exercise), Coral Use Last Rest Time (focused
//  last rest including warm-ups), Hematite This Exercise Last Rest
//  (any rest including warm-ups), and Azurite This Workout Last
//  Prescribed Rest action.
//

import AppIntents
import Foundation

struct ThisExerciseLastWorkingRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Last Working Rest"
    static var description = IntentDescription(
        "Hear the last working-set rest on the focused exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = KyaniteAskFitLog.thisExerciseLastWorkingRestDialog(
            snapshot: FitLogIntentBridge.loadKyaniteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
