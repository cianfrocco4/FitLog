//
//  ThisExerciseRemainingSetsQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts how many working sets (or the cardio duration)
//  remain on the focused exercise, without opening the app or changing
//  focus (`like.history.logged` / `like.rest.no_nag`). Distinct from
//  Jasper Sets Remaining (session-wide leftover), Spinel This Exercise
//  Sets (logged of prescribed), Moonstone Next Set (set N of M), and
//  Jasper Next Exercise (next incomplete name).
//

import AppIntents
import Foundation

struct ThisExerciseRemainingSetsQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Remaining Sets"
    static var description = IntentDescription(
        "Hear how many working sets remain on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = JadeAskFitLog.thisExerciseRemainingSetsDialog(
            snapshot: FitLogIntentBridge.loadJadeSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
