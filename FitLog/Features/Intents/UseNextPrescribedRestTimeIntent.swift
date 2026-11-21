//
//  UseNextPrescribedRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the next leftover exercise's
//  prescribed rest via Siri / Shortcuts (`like.history.logged`).
//  Does not start a rest timer, skip rest, add/subtract 30 seconds,
//  reset to the focused prescribed rest, double, halve, apply a
//  logged last rest, log a set, or invent rest when none is running
//  (`like.rest.no_nag`). Distinct from RestTimerIntent (starts rest),
//  Hematite Use Previous Prescribed Rest Time, Sunstone Use This
//  Workout Last Rest Time, Larimar Use Next Last Rest Time,
//  Turquoise Use Previous Last Rest Time, Coral Use Last Rest Time
//  (focused logged rest), Amber Double Rest Time, Jade Halve Rest
//  Time, Zircon Add Rest Time, Obsidian Subtract Rest Time,
//  Fluorite Reset Rest Time (focused prescribed), and Aquamarine
//  Skip Rest. Turquoise's Next Exercise Prescribed Rest is
//  query-only.
//

import AppIntents
import Foundation

struct UseNextPrescribedRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Next Prescribed Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the next leftover exercise's prescribed rest in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadMalachiteSessionSnapshot()
        if MalachiteAskFitLog.canUseNextPrescribedRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseNextPrescribedRestTime()
        }
        let message = MalachiteAskFitLog.useNextPrescribedRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
