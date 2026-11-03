//
//  ResumeInProgressWorkoutIntent.swift
//  FitLog
//
//  Re-open the in-progress workout via Siri / Shortcuts so logging can
//  continue after leaving the sheet (`like.history.logged`). Does not
//  start a new session and does not finish (`like.rest.no_nag`).
//  Distinct from Start Workout, Peridot Finish, and Sapphire Did I Train
//  Today.
//

import AppIntents
import Foundation

struct ResumeInProgressWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Workout"
    static var description = IntentDescription(
        "Re-open the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadLapisHistorySnapshot()
        if LapisAskFitLog.canResume(snapshot: snapshot) {
            FitLogIntentBridge.queueResumeWorkout()
        }
        let message = LapisAskFitLog.resumeWorkoutDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
