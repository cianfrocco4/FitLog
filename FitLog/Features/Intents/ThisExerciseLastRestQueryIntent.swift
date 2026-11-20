//
//  ThisExerciseLastRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the focused leftover last rested,
//  without opening the app (`like.history.logged` /
//  `like.rest.no_nag`). Warm-ups count; zero-second cardio does not
//  invent a rest. Distinct from Coral Use Last Rest Time (action on
//  the focused row), Larimar This Workout Last Rest (session-wide),
//  Amber This Last Rest, Turquoise Previous Exercise Last Rest, and
//  Sunstone Use This Workout Last Rest Time.
//

import AppIntents
import Foundation

struct ThisExerciseLastRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Last Rest"
    static var description = IntentDescription(
        "Hear the last rest logged on the focused exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = HematiteAskFitLog.thisExerciseLastRestDialog(
            snapshot: FitLogIntentBridge.loadHematiteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
