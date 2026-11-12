//
//  NextExerciseTargetQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the prescribed target on the next incomplete
//  exercise, without opening the app or changing focus
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from Zircon
//  This Exercise Target (focused row), Jasper Next Exercise (name),
//  and Alexandrite Go to Next (changes focus).
//

import AppIntents
import Foundation

struct NextExerciseTargetQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Target"
    static var description = IntentDescription(
        "Hear the prescribed sets and reps or cardio duration on the next incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = ObsidianAskFitLog.nextExerciseTargetDialog(
            snapshot: FitLogIntentBridge.loadObsidianSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
