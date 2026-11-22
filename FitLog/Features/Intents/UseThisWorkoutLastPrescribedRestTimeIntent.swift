//
//  UseThisWorkoutLastPrescribedRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the most recently finished strength
//  exercise's prescribed rest via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  add/subtract 30 seconds, reset to the focused prescribed rest,
//  double, halve, apply a logged last rest, log a set, or invent
//  rest when none is running (`like.rest.no_nag`). Distinct from
//  RestTimerIntent (starts rest), Malachite Use Next Prescribed
//  Rest Time (next leftover) and This Workout Last Prescribed Rest
//  (query only), Hematite Use Previous Prescribed Rest Time,
//  Sunstone Use This Workout Last Rest Time (logged rest), Larimar
//  Use Next Last Rest Time, Turquoise Use Previous Last Rest Time,
//  Coral Use Last Rest Time (focused logged rest), Amber Double
//  Rest Time, Jade Halve Rest Time, Zircon Add Rest Time, Obsidian
//  Subtract Rest Time, Fluorite Reset Rest Time (focused
//  prescribed), and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct UseThisWorkoutLastPrescribedRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use This Workout Last Prescribed Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the last finished strength exercise's prescribed rest in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadAzuriteSessionSnapshot()
        if AzuriteAskFitLog.canUseLastPrescribedRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseThisWorkoutLastPrescribedRestTime()
        }
        let message = AzuriteAskFitLog.useThisWorkoutLastPrescribedRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
