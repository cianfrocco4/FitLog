//
//  FinishWorkoutIntent.swift
//  FitLog
//
//  Finish the in-progress workout via Siri / Shortcuts and save it to
//  History (`like.history.logged` / real-user leftover after #54).
//  Empty sessions are not queued (`like.rest.no_nag`). Distinct from
//  the in-app finish-ready banner (999e) and from Start / Log Set /
//  Rest Timer.
//

import AppIntents
import Foundation

struct FinishWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Finish Workout"
    static var description = IntentDescription(
        "Finish the in-progress workout and save it to History in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadPeridotFinishSnapshot()
        if PeridotAskFitLog.canFinish(snapshot: snapshot) {
            FitLogIntentBridge.queueFinishWorkout()
        }
        let message = PeridotAskFitLog.finishWorkoutDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
