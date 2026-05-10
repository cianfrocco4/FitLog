//
//  StartWorkoutIntent.swift
//  FitLog
//
//  Start a workout via Siri or Shortcuts (Task 30).
//

import Foundation
import AppIntents

struct StartWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Workout"
    static var description = IntentDescription("Begin a new workout session in FitLog")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Workout Name", description: "Optional workout template name")
    var workoutName: String?
    
    func perform() async throws -> some IntentResult {
        // TODO: Wire to CurrentWorkoutSessionViewModel
        // If workoutName provided, find and start that workout
        // Otherwise start empty workout
        return .result()
    }
}
