//
//  PreviousExerciseTargetQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the prescribed target on the previous incomplete
//  exercise, without opening the app or changing focus
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from Spinel
//  Previous Exercise (name + last load), Spinel Go to Previous (changes
//  focus), Zircon This Exercise Target (focused), and Obsidian Next
//  Exercise Target.
//

import AppIntents
import Foundation

struct PreviousExerciseTargetQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Target"
    static var description = IntentDescription(
        "Hear the prescribed sets and reps or cardio duration on the previous incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = FluoriteAskFitLog.previousExerciseTargetDialog(
            snapshot: FitLogIntentBridge.loadFluoriteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
