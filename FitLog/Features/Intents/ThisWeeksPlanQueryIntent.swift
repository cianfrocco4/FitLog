//
//  ThisWeeksPlanQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts what this calendar week assigns (`like.plan.today`
//  / `improve.plan.checkmark`) without opening the app. Does not invent
//  workouts or start a session (`like.rest.no_nag`). Distinct from
//  Emerald This Week's Training (completed session count).
//

import AppIntents
import Foundation

struct ThisWeeksPlanQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Week's Plan"
    static var description = IntentDescription(
        "Hear this week's assigned workouts in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = OnyxAskFitLog.thisWeeksPlanDialog(
            snapshot: FitLogIntentBridge.loadOnyxNextPlanSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
