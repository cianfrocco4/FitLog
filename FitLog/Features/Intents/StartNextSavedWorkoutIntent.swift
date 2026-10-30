//
//  StartNextSavedWorkoutIntent.swift
//  FitLog
//
//  Start the next *different* saved library workout via Siri / Shortcuts
//  and speak last working load for that workout (`like.home.start_recent`
//  / `dislike.home.few_templates` / `improve.history.quick_log` /
//  `improve.home.last_weight`). Empty library does not queue a start
//  (`like.rest.no_nag`). Distinct from unnamed Start of last saved
//  library workout, Repeat Yesterday, Start Today's Workout, Start Last
//  Strength, and Start Tomorrow's Workout.
//

import AppIntents
import Foundation

struct StartNextSavedWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Next Saved Workout"
    static var description = IntentDescription(
        "Start the next saved workout in your library in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadGarnetLibrarySnapshot()
        if let name = GarnetAskFitLog.nextSavedWorkoutName(snapshot: snapshot) {
            FitLogIntentBridge.queueStartWorkout(named: name)
        }
        let message = GarnetAskFitLog.startNextSavedWorkoutDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
