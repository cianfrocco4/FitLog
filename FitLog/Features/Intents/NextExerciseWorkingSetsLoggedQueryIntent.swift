//
//  NextExerciseWorkingSetsLoggedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets are already logged
//  on the next exercise, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Warm-ups, cardio,
//  the focused row, and later rows beyond next do not count.
//  Distinct from Beryl Previous Exercise Working Sets Logged
//  (previous), Kyanite This Exercise Working Sets Logged
//  (focused), Spinel This Exercise Sets (includes warm-ups),
//  Jade This Exercise Remaining Sets, Tanzanite Sets Logged
//  (whole session), and Malachite This Workout Sets Completed.
//

import AppIntents
import Foundation

struct NextExerciseWorkingSetsLoggedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Working Sets Logged"
    static var description = IntentDescription(
        "Hear how many working sets are logged on the next exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = MorganiteAskFitLog.nextExerciseWorkingSetsLoggedDialog(
            snapshot: FitLogIntentBridge.loadMorganiteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
