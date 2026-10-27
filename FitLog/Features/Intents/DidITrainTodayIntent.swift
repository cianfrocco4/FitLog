//
//  DidITrainTodayIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts whether a session was already logged today
//  (`improve.home.already_trained`) without opening the app.
//

import AppIntents
import Foundation

struct DidITrainTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Did I Train Today"
    static var description = IntentDescription(
        "Hear whether you already logged a workout today in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = SapphireAskFitLog.didITrainTodayDialog(
            planTitle: WidgetSnapshotStore.read()?.todayPlanTitle,
            snapshot: FitLogIntentBridge.loadSapphireTodaySnapshot()
        )
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
