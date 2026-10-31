//
//  NextPlanWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which assigned training day comes next after
//  today (`like.plan.today` / `improve.home.last_weight`) without opening
//  the app. Rest days stay quiet (`like.rest.no_nag`). Distinct from
//  Ruby Today's Workout, Sapphire Start Today's Workout, Amethyst
//  Tomorrow's Workout, and Garnet Next Saved Workout.
//

import AppIntents
import Foundation

struct NextPlanWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Plan Workout"
    static var description = IntentDescription(
        "Hear the next planned training day after today in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = OnyxAskFitLog.nextPlanWorkoutDialog(
            snapshot: FitLogIntentBridge.loadOnyxNextPlanSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
