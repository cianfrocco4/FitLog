//
//  ThisExerciseWarmupSetsLoggedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many warm-up sets are already logged
//  on the focused exercise, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Working sets,
//  cardio, and other exercises do not count. Zero-second rest
//  still counts as a logged warm-up set. Distinct from Kunzite
//  This Workout Warmup Sets Logged (any row), Kyanite This
//  Exercise Working Sets Logged, Spinel This Exercise Sets
//  (includes working), Jade This Exercise Remaining Sets,
//  Tanzanite Sets Logged (whole session), and Malachite This
//  Workout Sets Completed.
//

import AppIntents
import Foundation

struct ThisExerciseWarmupSetsLoggedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Warmup Sets Logged"
    static var description = IntentDescription(
        "Hear how many warm-up sets are logged on the focused exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = HiddeniteAskFitLog.thisExerciseWarmupSetsLoggedDialog(
            snapshot: FitLogIntentBridge.loadHiddeniteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
