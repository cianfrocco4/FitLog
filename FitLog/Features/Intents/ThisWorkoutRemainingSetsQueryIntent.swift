//
//  ThisWorkoutRemainingSetsQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many leftover working sets remain across
//  the in-progress workout, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Cardio leftovers
//  count as one set if a duration is still needed. Distinct from Jade
//  This Exercise Remaining Sets (focused row), Amber Next Exercise
//  Remaining Sets, Coral Previous Exercise Remaining Sets, Jasper
//  Sets Remaining (focused), Alexandrite Remaining Exercises (row
//  count), and Tanzanite Sets Logged.
//

import AppIntents
import Foundation

struct ThisWorkoutRemainingSetsQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Remaining Sets"
    static var description = IntentDescription(
        "Hear how many working sets are left in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = SunstoneAskFitLog.thisWorkoutRemainingSetsDialog(
            snapshot: FitLogIntentBridge.loadSunstoneSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
