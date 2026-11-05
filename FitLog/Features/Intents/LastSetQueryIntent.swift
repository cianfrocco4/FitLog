//
//  LastSetQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts what the last working set or cardio duration
//  was in the in-progress workout (`improve.home.last_weight` /
//  `improve.cardio.home_duration` / `like.history.logged`) without
//  opening the app or logging anything. Distinct from Jasper Repeat
//  Last Set (copies a working set) and Peridot In-Progress (name +
//  set count already logged).
//

import AppIntents
import Foundation

struct LastSetQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Last Set"
    static var description = IntentDescription(
        "Hear the last working set or cardio duration in the in-progress workout in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = TourmalineAskFitLog.lastSetDialog(
            snapshot: FitLogIntentBridge.loadTourmalineSessionSnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
