//
//  TodayPlanQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts what is assigned today. Rest days stay quiet
//  (`like.rest.no_nag`) — the reply does not invent a workout.
//

import AppIntents
import Foundation

struct TodayPlanQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Workout"
    static var description = IntentDescription(
        "Hear today's assigned workout or rest day in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = RubyAskFitLog.todayPlanDialog(
            planTitle: WidgetSnapshotStore.read()?.todayPlanTitle
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
