//
//  ElapsedWorkoutQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how long the in-progress workout has been
//  going without opening the app (`like.rest.no_nag`). Distinct from
//  Aquamarine Rest Remaining (countdown) and Peridot In-Progress
//  Workout (whether a session is open).
//

import AppIntents
import Foundation

struct ElapsedWorkoutQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Elapsed Workout"
    static var description = IntentDescription(
        "Hear how long the in-progress workout has been going in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = TanzaniteAskFitLog.elapsedWorkoutDialog(
            snapshot: FitLogIntentBridge.loadTanzaniteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
