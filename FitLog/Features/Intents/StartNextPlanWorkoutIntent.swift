//
//  StartNextPlanWorkoutIntent.swift
//  FitLog
//
//  Start the next assigned training day after today via Siri / Shortcuts
//  and speak last working load for that workout (`like.plan.today` /
//  `like.home.start_recent` / `improve.history.quick_log` /
//  `improve.home.last_weight`). Rest / unscheduled days are skipped;
//  no upcoming training day does not queue a start (`like.rest.no_nag`).
//  Distinct from Start Today's Workout, Start Tomorrow's Workout, and
//  Start Next Saved Workout.
//

import AppIntents
import Foundation

struct StartNextPlanWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Next Plan Workout"
    static var description = IntentDescription(
        "Start the next planned training day after today in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadOnyxNextPlanSnapshot()
        if let name = OnyxAskFitLog.nextTrainingDay(snapshot: snapshot)?.workoutName {
            FitLogIntentBridge.queueStartWorkout(named: name)
        }
        let message = OnyxAskFitLog.startNextPlanWorkoutDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
