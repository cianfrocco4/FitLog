//
//  UseLastCardioDurationIntent.swift
//  FitLog
//
//  Log the last History cardio duration onto the unfinished cardio
//  row via Siri / Shortcuts so Zone 2 minutes do not require opening
//  History (`improve.cardio.home_duration` / `like.history.logged`).
//  Does not start a workout, finish one, or invent minutes when there
//  is no unfinished cardio or no previous duration (`like.rest.no_nag`).
//  Distinct from Jasper Repeat Last Set (strength working sets only)
//  and Log Set (requires weight/reps).
//

import AppIntents
import Foundation

struct UseLastCardioDurationIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Last Cardio Duration"
    static var description = IntentDescription(
        "Log the last cardio duration onto the unfinished cardio exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadTourmalineSessionSnapshot()
        if TourmalineAskFitLog.canApplyLastCardio(snapshot: snapshot) {
            FitLogIntentBridge.queueUseLastCardioDuration()
        }
        let message = TourmalineAskFitLog.useLastCardioDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
