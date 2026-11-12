//
//  NextExerciseLastWorkingQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the last working load or cardio duration logged
//  this session on the next incomplete exercise, without opening the
//  app or changing focus (`like.history.logged` / `like.rest.no_nag`).
//  Distinct from Citrine last-load (history), Tourmaline Last Set
//  (session-wide last set), Alexandrite Remaining (names), and
//  Alexandrite Go to Next (changes focus).
//

import AppIntents
import Foundation

struct NextExerciseLastWorkingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Last Working"
    static var description = IntentDescription(
        "Hear the last working set or cardio duration on the next incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = ObsidianAskFitLog.nextExerciseLastWorkingDialog(
            snapshot: FitLogIntentBridge.loadObsidianSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
