//
//  PreviousExerciseRemainingSetsQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets (or the cardio duration)
//  remain on the previous incomplete exercise, without opening the app or
//  changing focus (`like.history.logged` / `like.rest.no_nag`). Distinct
//  from Amber Next Exercise Remaining Sets, Jade This Exercise Remaining
//  Sets (focused row), Jasper Sets Remaining (session-wide leftover),
//  Fluorite Previous Exercise Target / This Last Working, Spinel Go to
//  Previous (changes focus), and Moonstone Next Set (set N of M).
//

import AppIntents
import Foundation

struct PreviousExerciseRemainingSetsQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Remaining Sets"
    static var description = IntentDescription(
        "Hear how many working sets remain on the previous incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = CoralAskFitLog.previousExerciseRemainingSetsDialog(
            snapshot: FitLogIntentBridge.loadCoralSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
