//
//  NextExerciseLastRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the last rest duration logged this session on
//  the next incomplete exercise, without opening the app or changing
//  focus (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Amber This Exercise Last Rest (focused row), Zircon Prescribed Rest
//  (plan default), Aquamarine Rest Remaining (live countdown), Obsidian
//  Next Exercise Last Working (load), and Amber Next Exercise Remaining
//  Sets (leftover count).
//

import AppIntents
import Foundation

struct NextExerciseLastRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Last Rest"
    static var description = IntentDescription(
        "Hear the last rest duration logged on the next incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = CoralAskFitLog.nextExerciseLastRestDialog(
            snapshot: FitLogIntentBridge.loadCoralSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
