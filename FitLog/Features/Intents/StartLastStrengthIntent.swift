//
//  StartLastStrengthIntent.swift
//  FitLog
//
//  Start the last completed strength workout via Siri / Shortcuts and
//  speak last working load (`like.home.start_recent` /
//  `improve.history.quick_log` / `improve.home.last_weight`). Cardio-only
//  history is skipped. Distinct from Repeat Yesterday (any last session)
//  and Start Last Cardio.
//

import AppIntents
import Foundation

struct StartLastStrengthIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Last Strength"
    static var description = IntentDescription(
        "Start your last strength workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadEmeraldStrengthSnapshot()
        if let name = snapshot?.lastStrengthWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            FitLogIntentBridge.queueStartWorkout(named: name)
        }
        let message = EmeraldAskFitLog.startLastStrengthDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
