//
//  ThisWorkoutWarmupSetsLoggedQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many warm-up sets are already logged
//  in this session, without opening the app (`like.history.logged`
//  / `like.rest.no_nag`). Working sets, cardio, and placeholders
//  do not count. Zero-second rest still counts as a logged
//  warm-up set. Distinct from Iolite This Workout Last Completed
//  Strength, Kyanite This Exercise Working Sets Logged, Beryl
//  Previous Exercise Working Sets Logged, Morganite Next Exercise
//  Working Sets Logged, Spinel This Exercise Sets (includes
//  warm-ups on the focused row), Malachite This Workout Sets
//  Completed, Tanzanite Sets Logged (whole session), and Jade
//  This Exercise Remaining Sets.
//

import AppIntents
import Foundation

struct ThisWorkoutWarmupSetsLoggedQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Warmup Sets Logged"
    static var description = IntentDescription(
        "Hear how many warm-up sets are already logged in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = KunziteAskFitLog.thisWorkoutWarmupSetsLoggedDialog(
            snapshot: FitLogIntentBridge.loadKunziteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
