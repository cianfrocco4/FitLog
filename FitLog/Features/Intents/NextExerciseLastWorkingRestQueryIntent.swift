//
//  NextExerciseLastWorkingRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the most recently logged
//  working-set rest on the next exercise lasted, without
//  opening the app (`like.history.logged` / `like.rest.no_nag`).
//  Warm-ups, cardio, the focused row, later rows beyond next, and
//  zero-second rest do not invent a duration. Distinct from
//  Beryl Previous Exercise Last Working Rest (previous), Kyanite
//  This Exercise Last Working Rest (focused), Iolite This
//  Workout Last Working Rest (any exercise), Larimar Use Next
//  Last Rest Time (including warm-ups), Malachite Use Next
//  Prescribed Rest Time, and Azurite This Workout Last
//  Prescribed Rest action.
//

import AppIntents
import Foundation

struct NextExerciseLastWorkingRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Last Working Rest"
    static var description = IntentDescription(
        "Hear the last working-set rest on the next exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = MorganiteAskFitLog.nextExerciseLastWorkingRestDialog(
            snapshot: FitLogIntentBridge.loadMorganiteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
