//
//  LastFinishedWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which workout last landed in History
//  (`like.history.logged` / `improve.history.quick_log`) without opening
//  the app. Speaks last working load (skips warm-ups) or last cardio
//  duration. Distinct from Citrine Last Workout (completed name/load
//  query used for starting context) and Amethyst Last Session Duration.
//

import AppIntents
import Foundation

struct LastFinishedWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Finished Workout"
    static var description = IntentDescription(
        "Hear the last workout saved to History in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = PeridotAskFitLog.lastFinishedWorkoutDialog(
            snapshot: FitLogIntentBridge.loadPeridotFinishSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
