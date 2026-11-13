//
//  ThisExerciseLastWorkingQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts the last working load or cardio duration logged
//  this session on the focused exercise, without opening the app or
//  changing focus (`like.history.logged` / `like.rest.no_nag`). Distinct
//  from Citrine last-load (history), Tourmaline Last Set (session-wide),
//  Obsidian Next Exercise Last Working (next incomplete row), and
//  Spinel This Exercise Sets (logged vs prescribed count).
//

import AppIntents
import Foundation

struct ThisExerciseLastWorkingQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Exercise Last Working"
    static var description = IntentDescription(
        "Hear the last working set or cardio duration on the focused exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = FluoriteAskFitLog.thisExerciseLastWorkingDialog(
            snapshot: FitLogIntentBridge.loadFluoriteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
