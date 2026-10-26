//
//  RepeatYesterdayIntent.swift
//  FitLog
//
//  Start the last completed workout via Siri / Shortcuts (repeat yesterday).
//  Distinct from StartWorkoutIntent (Topaz unnamed start of a saved library
//  workout) and LastWorkoutQueryIntent (Citrine, query-only).
//

import AppIntents
import Foundation

struct RepeatYesterdayIntent: AppIntent {
    static var title: LocalizedStringResource = "Repeat Yesterday"
    static var description = IntentDescription(
        "Start your last completed workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadRubyRepeatSnapshot()
        if let name = snapshot?.lastWorkoutName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            FitLogIntentBridge.queueStartWorkout(named: name)
        }
        let message = RubyAskFitLog.repeatYesterdayDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
