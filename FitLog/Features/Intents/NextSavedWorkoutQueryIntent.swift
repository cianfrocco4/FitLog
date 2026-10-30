//
//  NextSavedWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which saved library workout comes next after the
//  last completed one (`dislike.home.few_templates` /
//  `like.home.start_recent` / `improve.home.last_weight`) without opening
//  the app. Distinct from Ruby Today's Workout, Sapphire Start Today's
//  Workout, and Amethyst Tomorrow's Workout.
//

import AppIntents
import Foundation

struct NextSavedWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Saved Workout"
    static var description = IntentDescription(
        "Hear the next saved workout in your library in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = GarnetAskFitLog.nextSavedWorkoutDialog(
            snapshot: FitLogIntentBridge.loadGarnetLibrarySnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
