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
    static var description = IntentDescription("Log a set for the current exercise in FitLog")
    static var openAppWhenRun: Bool = false
    
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
        // Validate active workout
        // TODO: Check CurrentWorkoutSessionViewModel.currentSession
        guard weight > 0, reps > 0 else {
            throw $weight.needsValueError("Weight must be greater than zero")
        }
        
        if let rpe = rpe {
            guard rpe >= 6.0 && rpe <= 10.0 else {
                throw $rpe.needsValueError("RPE must be between 6 and 10")
            }
        }
        
        // TODO: Wire to CurrentWorkoutSessionViewModel.logSet
        // If no active workout, return suggestedFollowUp to start one
        
        let message = "Logged \(reps) reps at \(Int(weight)) lbs"
        return .result(value: message)
    }
}
