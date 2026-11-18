//
//  PreviousExercisePrescribedRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the prescribed rest duration on the previous
//  incomplete exercise, without opening the app or changing focus
//  (`like.history.logged` / `like.rest.no_nag`). Session rest override
//  wins over the library default. Distinct from Turquoise Next Exercise
//  Prescribed Rest (next incomplete row), Zircon Prescribed Rest
//  (focused row), Turquoise Previous Exercise Last Rest (logged rest),
//  Coral Next Exercise Last Rest, Aquamarine Rest Remaining (live
//  countdown), Fluorite Previous Exercise Target, and Jade Previous
//  Exercise Last Working (load).
//

import AppIntents
import Foundation

struct PreviousExercisePrescribedRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Exercise Prescribed Rest"
    static var description = IntentDescription(
        "Hear the prescribed rest duration on the previous incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = LarimarAskFitLog.previousExercisePrescribedRestDialog(
            snapshot: FitLogIntentBridge.loadLarimarSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
