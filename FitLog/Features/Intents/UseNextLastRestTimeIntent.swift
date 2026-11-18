//
//  UseNextLastRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the next incomplete exercise's last
//  logged rest via Siri / Shortcuts (`like.history.logged`). Does not
//  start a rest timer, skip rest, add/subtract 30 seconds, reset to
//  prescribed, double, halve, apply the focused row's last rest, or
//  apply the previous row's last rest, log a set, or invent rest when
//  none is running (`like.rest.no_nag`). Distinct from RestTimerIntent
//  (starts rest), Turquoise Use Previous Last Rest Time, Coral Use Last
//  Rest Time (focused row), Amber Double Rest Time, Jade Halve Rest
//  Time, Zircon Add Rest Time, Obsidian Subtract Rest Time, Fluorite
//  Reset Rest Time, and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct UseNextLastRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Next Last Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the last rest logged on the next incomplete exercise in Workout Log AI"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadLarimarSessionSnapshot()
        if LarimarAskFitLog.canUseNextLastRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseNextLastRestTime()
        }
        let message = LarimarAskFitLog.useNextLastRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
