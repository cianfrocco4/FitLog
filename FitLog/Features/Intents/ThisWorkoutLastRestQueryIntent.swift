//
//  ThisWorkoutLastRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the most recently logged rest duration anywhere
//  in the in-progress workout, including completed rows, without
//  opening the app (`like.history.logged` / `like.rest.no_nag`). Distinct
//  from Amber This Exercise Last Rest (focused row), Coral Next
//  Exercise Last Rest, Turquoise Previous Exercise Last Rest, Aquamarine
//  Rest Remaining (live countdown), and Zircon Prescribed Rest (plan
//  default on the focused row).
//

import AppIntents
import Foundation

struct ThisWorkoutLastRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Rest"
    static var description = IntentDescription(
        "Hear the last rest duration logged anywhere in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = LarimarAskFitLog.thisWorkoutLastRestDialog(
            snapshot: FitLogIntentBridge.loadLarimarSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
