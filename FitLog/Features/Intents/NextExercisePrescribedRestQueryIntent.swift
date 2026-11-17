//
//  NextExercisePrescribedRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the prescribed rest duration on the next
//  incomplete exercise, without opening the app or changing focus
//  (`like.history.logged` / `like.rest.no_nag`). Session rest override
//  wins over the library default. Distinct from Zircon Prescribed Rest
//  (focused row), Coral Next Exercise Last Rest (logged rest),
//  Aquamarine Rest Remaining (live countdown), Obsidian Next Exercise
//  Target / Last Working, and Amber Next Exercise Remaining Sets
//  (leftover count).
//

import AppIntents
import Foundation

struct NextExercisePrescribedRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Exercise Prescribed Rest"
    static var description = IntentDescription(
        "Hear the prescribed rest duration on the next incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = TurquoiseAskFitLog.nextExercisePrescribedRestDialog(
            snapshot: FitLogIntentBridge.loadTurquoiseSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
