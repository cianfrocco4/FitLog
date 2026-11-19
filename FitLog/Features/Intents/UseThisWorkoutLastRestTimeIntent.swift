//
//  UseThisWorkoutLastRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the most recently logged rest anywhere
//  in the in-progress workout via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  add/subtract 30 seconds, reset to prescribed, double, halve, apply
//  the focused / previous / next row's last rest, log a set, or invent
//  rest when none is running (`like.rest.no_nag`). Distinct from
//  RestTimerIntent (starts rest), Larimar Use Next Last Rest Time,
//  Turquoise Use Previous Last Rest Time, Coral Use Last Rest Time
//  (focused row), Amber Double Rest Time, Jade Halve Rest Time,
//  Zircon Add Rest Time, Obsidian Subtract Rest Time, Fluorite Reset
//  Rest Time, and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct UseThisWorkoutLastRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use This Workout Last Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the last rest logged anywhere in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadSunstoneSessionSnapshot()
        if SunstoneAskFitLog.canUseThisWorkoutLastRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseThisWorkoutLastRestTime()
        }
        let message = SunstoneAskFitLog.useThisWorkoutLastRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
