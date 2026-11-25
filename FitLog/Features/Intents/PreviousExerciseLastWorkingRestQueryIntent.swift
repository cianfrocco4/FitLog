//
//  PreviousExerciseLastWorkingRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged
//  working-set rest on the previous exercise lasted, without
//  opening the app (`like.history.logged` / `like.rest.no_nag`).
//  Warm-ups, cardio, the focused row, earlier rows, and
//  zero-second rest do not invent a duration. Distinct from
//  Kyanite This Exercise Last Working Rest (focused), Iolite This
//  Workout Last Working Rest (any exercise), Turquoise Use
//  Previous Last Rest Time (including warm-ups), Hematite This
//  Exercise Last Rest (any rest including warm-ups), and Azurite
//  This Workout Last Prescribed Rest action.
//

import AppIntents
import Foundation

struct PreviousExerciseLastWorkingRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Last Working Rest"
    static var description = IntentDescription(
        "Hear the last working-set rest on the previous exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = BerylAskFitLog.previousExerciseLastWorkingRestDialog(
            snapshot: FitLogIntentBridge.loadBerylSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
