//
//  ThisWorkoutLastPrescribedRestQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts what rest the most recently finished
//  startable strength exercise called for, without opening the app
//  (`like.history.logged` / `like.rest.no_nag`). Session override
//  wins; cardio completed rows are skipped. Distinct from Zircon
//  Prescribed Rest (focused row), Larimar Previous Exercise
//  Prescribed Rest (leftover query), Turquoise Next Exercise
//  Prescribed Rest (leftover query), Hematite Use Previous
//  Prescribed Rest Time (action), and this branch's Use Next
//  Prescribed Rest Time (action).
//

import AppIntents
import Foundation

struct ThisWorkoutLastPrescribedRestQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "This Workout Last Prescribed Rest"
    static var description = IntentDescription(
        "Hear the prescribed rest of the last finished strength exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = MalachiteAskFitLog.thisWorkoutLastPrescribedRestDialog(
            snapshot: FitLogIntentBridge.loadMalachiteSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
