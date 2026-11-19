//
//  ThisWorkoutLastWorkingQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the most recently logged working load (or
//  cardio duration) anywhere in the in-progress workout, including
//  completed rows, without opening the app (`like.history.logged` /
//  `like.rest.no_nag`). Distinct from Jade Previous Exercise Last
//  Working, Fluorite This Exercise Last Working, Obsidian Next
//  Exercise Last Working, Tourmaline Last Set, Citrine last-load
//  (history), and Larimar This Workout Last Rest (rest duration).
//

import AppIntents
import Foundation

struct ThisWorkoutLastWorkingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Working"
    static var description = IntentDescription(
        "Hear the last working load logged anywhere in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = SunstoneAskFitLog.thisWorkoutLastWorkingDialog(
            snapshot: FitLogIntentBridge.loadSunstoneSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
