//
//  RestTimerIntent.swift
//  FitLog
//
//  Start rest timer via Siri or Shortcuts (Task 30).
//

import Foundation
import AppIntents

struct RestTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Rest Timer"
    static var description = IntentDescription("Start a rest timer in Workout Log AI")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Duration", description: "Rest duration in seconds", default: 90)
    var durationSeconds: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$durationSeconds) second rest timer")
    }

    func perform() async throws -> some IntentResult {
        guard durationSeconds > 0 && durationSeconds <= 600 else {
            throw $durationSeconds.needsValueError("Duration must be between 1 and 600 seconds")
        }

        FitLogIntentBridge.queueRestTimer(seconds: durationSeconds)
        return .result()
    }
}
