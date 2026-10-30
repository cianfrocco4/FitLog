//
//  SavedWorkoutsQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts which workouts are saved in the library
//  (`like.library.templates` / `dislike.home.few_templates`) without
//  opening the app. Does not invent workouts or start a session
//  (`like.rest.no_nag`).
//

import AppIntents
import Foundation

struct SavedWorkoutsQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "My Saved Workouts"
    static var description = IntentDescription(
        "Hear the workouts saved in your library in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = GarnetAskFitLog.savedWorkoutsDialog(
            snapshot: FitLogIntentBridge.loadGarnetLibrarySnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
