//
//  StartTodaysWorkoutIntent.swift
//  FitLog
//
//  Start today's assigned plan via Siri / Shortcuts. Rest days stay quiet
//  (`like.rest.no_nag`) and do not queue a workout. Distinct from
//  TodayPlanQueryIntent (Ruby, query-only) and RepeatYesterdayIntent
//  (last completed session).
//

import AppIntents
import Foundation

struct StartTodaysWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Today's Workout"
    static var description = IntentDescription(
        "Start today's assigned workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let planTitle = WidgetSnapshotStore.read()?.todayPlanTitle
        if SapphireAskFitLog.isStartablePlanTitle(planTitle) {
            FitLogIntentBridge.queueStartWorkout(named: planTitle)
        }
        let message = SapphireAskFitLog.startTodaysWorkoutDialog(
            planTitle: planTitle,
            snapshot: FitLogIntentBridge.loadSapphireTodaySnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
