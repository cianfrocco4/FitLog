//
//  FocusNextExerciseIntent.swift
//  FitLog
//
//  Switch focus to the next incomplete exercise via Siri / Shortcuts
//  without marking the current row done (`like.history.logged`). Does
//  not start a workout, skip remaining sets, or invent a focus change
//  when there is no other incomplete row (`like.rest.no_nag`). Distinct
//  from Moonstone Skip Remaining Sets (marks done), Jasper Next
//  Exercise (query only), and Tourmaline Current Exercise (query only).
//

import AppIntents
import Foundation

struct FocusNextExerciseIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to Next Exercise"
    static var description = IntentDescription(
        "Focus the next incomplete exercise in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadAlexandriteSessionSnapshot()
        if AlexandriteAskFitLog.canFocusNext(snapshot: snapshot) {
            FitLogIntentBridge.queueFocusNextExercise()
        }
        let message = AlexandriteAskFitLog.focusNextDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
