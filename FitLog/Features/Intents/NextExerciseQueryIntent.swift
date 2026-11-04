//
//  NextExerciseQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which in-progress exercise still needs work
//  and speak last working load (skips warm-ups) or last cardio
//  duration (`improve.home.last_weight` / `improve.cardio.home_duration`).
//  Distinct from Lapis Last Session Exercises (History) and Citrine
//  last-workout queries.
//

import AppIntents
import Foundation

struct NextExerciseQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise"
    static var description = IntentDescription(
        "Hear the next exercise that still needs work in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = JasperAskFitLog.nextExerciseDialog(
            snapshot: FitLogIntentBridge.loadJasperSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
