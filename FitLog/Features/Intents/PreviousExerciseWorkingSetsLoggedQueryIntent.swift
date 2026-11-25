//
//  PreviousExerciseWorkingSetsLoggedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets are already logged
//  on the previous exercise, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Warm-ups, cardio,
//  the focused row, and earlier rows do not count. Distinct from
//  Kyanite This Exercise Working Sets Logged (focused), Spinel
//  This Exercise Sets (includes warm-ups), Jade This Exercise
//  Remaining Sets, Tanzanite Sets Logged (whole session), and
//  Malachite This Workout Sets Completed.
//

import AppIntents
import Foundation

struct PreviousExerciseWorkingSetsLoggedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Working Sets Logged"
    static var description = IntentDescription(
        "Hear how many working sets are logged on the previous exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = BerylAskFitLog.previousExerciseWorkingSetsLoggedDialog(
            snapshot: FitLogIntentBridge.loadBerylSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
