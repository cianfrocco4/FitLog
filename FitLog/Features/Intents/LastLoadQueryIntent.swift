//
//  LastLoadQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts for last working weight (or last cardio duration)
//  without opening Home. Optional exercise name narrows the answer.
//

import AppIntents
import Foundation

struct LastLoadQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Working Load"
    static var description = IntentDescription(
        "Hear last working weight or last cardio duration in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Exercise", description: "Optional exercise to look up")
    var exercise: ExerciseEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Last working load") {
            \.$exercise
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadLastLoadQuerySnapshot()
        let message = CitrineLastWorkingLoad.lastLoadDialog(
            exerciseName: exercise?.name,
            snapshot: snapshot
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
