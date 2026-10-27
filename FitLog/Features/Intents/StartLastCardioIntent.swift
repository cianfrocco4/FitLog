//
//  StartLastCardioIntent.swift
//  FitLog
//
//  Start the last completed cardio workout via Siri / Shortcuts and speak
//  last duration (`improve.cardio.home_duration`). Distinct from Repeat
//  Yesterday (any last session) and Topaz unnamed Start (last saved library).
//

import AppIntents
import Foundation

struct StartLastCardioIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Last Cardio"
    static var description = IntentDescription(
        "Start your last cardio workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadSapphireTodaySnapshot()
        if let name = snapshot?.lastCardioWorkoutName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            FitLogIntentBridge.queueStartWorkout(named: name)
        }
        let message = SapphireAskFitLog.startLastCardioDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
