//
//  UseThisExerciseLastWorkingRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the focused exercise's most recently
//  logged working-set rest via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  add/subtract 30 seconds, reset to the focused prescribed rest,
//  double, halve, apply a warmup rest, apply a prescribed rest,
//  apply this workout's last working rest from another exercise,
//  log a set, or invent rest when none is running
//  (`like.rest.no_nag`). Distinct from RestTimerIntent (starts
//  rest), Iolite Use This Workout Last Working Rest Time (any
//  exercise), Azurite Use This Workout Last Prescribed Rest Time,
//  Malachite Use Next Prescribed Rest Time, Hematite Use Previous
//  Prescribed Rest Time, Sunstone Use This Workout Last Rest Time
//  (any logged rest, including warm-ups), Larimar Use Next Last
//  Rest Time, Turquoise Use Previous Last Rest Time, Coral Use
//  Last Rest Time (focused logged rest including warm-ups), Amber
//  Double Rest Time, Jade Halve Rest Time, Zircon Add Rest Time,
//  Obsidian Subtract Rest Time, Fluorite Reset Rest Time (focused
//  prescribed), and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct UseThisExerciseLastWorkingRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use This Exercise Last Working Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the last working-set rest on the focused exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadKyaniteSessionSnapshot()
        if KyaniteAskFitLog.canUseLastWorkingRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseThisExerciseLastWorkingRestTime()
        }
        let message = KyaniteAskFitLog.useThisExerciseLastWorkingRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
