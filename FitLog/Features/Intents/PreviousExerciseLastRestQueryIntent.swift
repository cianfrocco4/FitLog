//
//  PreviousExerciseLastRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the last rest duration logged this session on
//  the previous incomplete exercise, without opening the app or changing
//  focus (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Coral Next Exercise Last Rest (next incomplete row), Amber This
//  Exercise Last Rest (focused row), Zircon Prescribed Rest (plan
//  default on the focused row), Aquamarine Rest Remaining (live
//  countdown), Jade Previous Exercise Last Working (load), and Coral
//  Previous Exercise Remaining Sets (leftover count).
//

import AppIntents
import Foundation

struct PreviousExerciseLastRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Last Rest"
    static var description = IntentDescription(
        "Hear the last rest duration logged on the previous incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = TurquoiseAskFitLog.previousExerciseLastRestDialog(
            snapshot: FitLogIntentBridge.loadTurquoiseSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
