//
//  CurrentExerciseQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which in-progress exercise is focused and
//  speak last working load (skips warm-ups) or last cardio duration
//  (`improve.home.last_weight` / `improve.cardio.home_duration`).
//  Distinct from Jasper Next Exercise (next incomplete row) and
//  Lapis Last Session Exercises (History).
//

import AppIntents
import Foundation

struct CurrentExerciseQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Current Exercise"
    static var description = IntentDescription(
        "Hear the current exercise in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = TourmalineAskFitLog.currentExerciseDialog(
            snapshot: FitLogIntentBridge.loadTourmalineSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
