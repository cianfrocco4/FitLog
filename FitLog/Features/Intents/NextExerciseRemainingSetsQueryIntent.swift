//
//  NextExerciseRemainingSetsQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets (or the cardio duration)
//  remain on the next incomplete exercise, without opening the app or
//  changing focus (`like.history.logged` / `like.rest.no_nag`). Distinct
//  from Jade This Exercise Remaining Sets (focused row), Jasper Sets
//  Remaining (session-wide leftover), Obsidian Next Exercise Target /
//  Last Working, Alexandrite Go to Next (changes focus), and Moonstone
//  Next Set (set N of M).
//

import AppIntents
import Foundation

struct NextExerciseRemainingSetsQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Remaining Sets"
    static var description = IntentDescription(
        "Hear how many working sets remain on the next incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AmberAskFitLog.nextExerciseRemainingSetsDialog(
            snapshot: FitLogIntentBridge.loadAmberSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
