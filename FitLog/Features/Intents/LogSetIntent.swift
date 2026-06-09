//
//  LogSetIntent.swift
//  FitLog
//
//  Log a set via Siri or Shortcuts (Task 30).
//

import Foundation
import AppIntents

struct LogSetIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Set"
    static var description = IntentDescription("Log a set for the current exercise in The Workout Log")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Exercise", description: "Exercise name")
    var exercise: ExerciseEntity?

    @Parameter(title: "Weight", description: "Weight lifted in pounds")
    var weight: Double

    @Parameter(title: "Reps", description: "Number of repetitions")
    var reps: Int

    @Parameter(title: "RPE", description: "Optional rating of perceived exertion (6-10)")
    var rpe: Double?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$reps) reps at \(\.$weight) lbs") {
            \.$exercise
            \.$rpe
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard reps > 0 else {
            throw $reps.needsValueError("Reps must be greater than zero")
        }
        guard weight >= 0 else {
            throw $weight.needsValueError("Weight cannot be negative")
        }

        if let rpe = rpe {
            guard rpe >= 6.0 && rpe <= 10.0 else {
                throw $rpe.needsValueError("RPE must be between 6 and 10")
            }
        }

        FitLogIntentBridge.queueLogSet(
            FitLogIntentBridge.PendingLogSet(
                exerciseId: exercise?.id,
                weight: weight,
                reps: reps,
                rpe: rpe
            )
        )

        let message = "Queued \(reps) reps at \(Int(weight)) lbs — open \(AppBrand.name) to apply"
        return .result(value: message)
    }
}
