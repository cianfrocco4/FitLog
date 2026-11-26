//
//  UseNextExerciseLastWorkingRestTimeIntent.swift
//  FitLog
//
//  Set a live rest countdown to the next exercise's most
//  recently logged working-set rest via Siri / Shortcuts
//  (`like.history.logged`). Does not start a rest timer, skip rest,
//  add/subtract 30 seconds, reset to the focused prescribed rest,
//  double, halve, apply a warmup rest, apply a prescribed rest,
//  apply this workout's last working rest from any exercise,
//  apply the focused lift's last working rest, apply the previous
//  lift's last working rest, log a set, go to the next exercise,
//  or invent rest when none is running (`like.rest.no_nag`).
//  Distinct from RestTimerIntent (starts rest), Beryl Use
//  Previous Exercise Last Working Rest Time (previous row),
//  Kyanite Use This Exercise Last Working Rest Time (focused
//  row), Iolite Use This Workout Last Working Rest Time (any
//  exercise), Azurite Use This Workout Last Prescribed Rest
//  Time, Malachite Use Next Prescribed Rest Time, Hematite Use
//  Previous Prescribed Rest Time, Sunstone Use This Workout Last
//  Rest Time (any logged rest, including warm-ups), Larimar Use
//  Next Last Rest Time (including warm-ups), Turquoise Use
//  Previous Last Rest Time (including warm-ups), Coral Use Last
//  Rest Time (focused logged rest including warm-ups), Amber
//  Double Rest Time, Jade Halve Rest Time, Zircon Add Rest Time,
//  Obsidian Subtract Rest Time, Fluorite Reset Rest Time
//  (focused prescribed), Alexandrite Focus Next Exercise, Spinel
//  Focus Previous Exercise, and Aquamarine Skip Rest.
//

import AppIntents
import Foundation

struct UseNextExerciseLastWorkingRestTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Use Next Exercise Last Working Rest Time"
    static var description = IntentDescription(
        "Set the live rest countdown to the last working-set rest on the next exercise in the current Workout Log AI session"
    )
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let snapshot = FitLogIntentBridge.loadMorganiteSessionSnapshot()
        if MorganiteAskFitLog.canUseLastWorkingRest(snapshot: snapshot) {
            FitLogIntentBridge.queueUseNextExerciseLastWorkingRestTime()
        }
        let message = MorganiteAskFitLog.useNextExerciseLastWorkingRestDialog(snapshot: snapshot)
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
