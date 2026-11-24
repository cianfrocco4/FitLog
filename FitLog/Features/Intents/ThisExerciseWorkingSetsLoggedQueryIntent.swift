//
//  ThisExerciseWorkingSetsLoggedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets are already logged
//  on the focused exercise, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Warm-ups, cardio,
//  and other exercises do not count. Distinct from Spinel This
//  Exercise Sets (includes warm-ups), Jade This Exercise Remaining
//  Sets, Tanzanite Sets Logged (whole session), and Malachite This
//  Workout Sets Completed.
//

import AppIntents
import Foundation

struct ThisExerciseWorkingSetsLoggedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Working Sets Logged"
    static var description = IntentDescription(
        "Hear how many working sets are logged on the focused exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = KyaniteAskFitLog.thisExerciseWorkingSetsLoggedDialog(
            snapshot: FitLogIntentBridge.loadKyaniteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
