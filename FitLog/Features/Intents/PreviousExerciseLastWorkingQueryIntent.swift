//
//  PreviousExerciseLastWorkingQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the last working load or cardio duration logged
//  this session on the previous incomplete exercise, without opening
//  the app or changing focus (`like.history.logged` / `like.rest.no_nag`).
//  Distinct from Fluorite Previous Exercise Target (prescription),
//  Spinel Previous Exercise (name + last load), Spinel Go to Previous
//  (changes focus), Obsidian Next Exercise Last Working, Fluorite This
//  Exercise Last Working, and Citrine last-load (history).
//

import AppIntents
import Foundation

struct PreviousExerciseLastWorkingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Last Working"
    static var description = IntentDescription(
        "Hear the last working set or cardio duration on the previous incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = JadeAskFitLog.previousExerciseLastWorkingDialog(
            snapshot: FitLogIntentBridge.loadJadeSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
