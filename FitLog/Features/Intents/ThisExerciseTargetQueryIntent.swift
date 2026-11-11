//
//  ThisExerciseTargetQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the prescribed target on the focused exercise,
//  without opening the app or logging anything (`like.history.logged`
//  / `like.rest.no_nag`). Distinct from Spinel This Exercise Sets
//  (logged vs prescribed count) and Moonstone Next Set (next unlogged
//  working set number).
//

import AppIntents
import Foundation

struct ThisExerciseTargetQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Target"
    static var description = IntentDescription(
        "Hear the prescribed sets and reps or cardio duration on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = ZirconAskFitLog.thisExerciseTargetDialog(
            snapshot: FitLogIntentBridge.loadZirconSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
