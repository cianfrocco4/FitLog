//
//  ThisExerciseLastRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the last rest duration logged this session on
//  the focused exercise, without opening the app or changing focus
//  (`like.history.logged` / `like.rest.no_nag`). Distinct from Zircon
//  Prescribed Rest (plan default), Aquamarine Rest Remaining (live
//  countdown), Fluorite This Exercise Last Working (load), and Jade
//  This Exercise Remaining Sets (leftover count).
//

import AppIntents
import Foundation

struct ThisExerciseLastRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Last Rest"
    static var description = IntentDescription(
        "Hear the last rest duration logged on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = AmberAskFitLog.thisExerciseLastRestDialog(
            snapshot: FitLogIntentBridge.loadAmberSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
