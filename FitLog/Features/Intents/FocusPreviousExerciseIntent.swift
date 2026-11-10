//
//  FocusPreviousExerciseIntent.swift
//  FitLog
//
//  Switch focus to the previous incomplete exercise via Siri / Shortcuts
//  without marking the current row done (`like.history.logged`). Does
//  not start a workout, skip remaining sets, or invent a focus change
//  when there is no other incomplete row (`like.rest.no_nag`). Distinct
//  from Alexandrite Go to Next Exercise and Moonstone Skip Remaining
//  Sets (marks done).
//

import AppIntents
import Foundation

struct FocusPreviousExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to Previous Exercise"
    static var description = IntentDescription(
        "Focus the previous incomplete exercise in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadSpinelSessionSnapshot()
        if SpinelAskFitLog.canFocusPrevious(snapshot: snapshot) {
            FitLogIntentBridge.queueFocusPreviousExercise()
        }
        let message = SpinelAskFitLog.focusPreviousDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
