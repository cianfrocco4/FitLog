//
//  StartTomorrowsWorkoutIntent.swift
//  FitLog
//
//  Start tomorrow's assigned plan via Siri / Shortcuts and speak last
//  working load for that workout (`like.plan.today` /
//  `like.home.start_recent` / `improve.history.quick_log` /
//  `improve.home.last_weight`). Rest / no plan do not queue a start
//  (`like.rest.no_nag`). Distinct from Start Today's Workout.
//

import AppIntents
import Foundation

struct StartTomorrowsWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Tomorrow's Workout"
    static var description = IntentDescription(
        "Start tomorrow's planned workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadAmethystTomorrowSnapshot()
        if AmethystAskFitLog.isStartablePlanTitle(snapshot?.tomorrowPlanTitle),
           let name = snapshot?.tomorrowPlanTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            FitLogIntentBridge.queueStartWorkout(named: name)
        }
        let message = AmethystAskFitLog.startTomorrowsWorkoutDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
