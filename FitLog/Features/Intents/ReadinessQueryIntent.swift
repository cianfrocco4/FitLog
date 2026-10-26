//
//  ReadinessQueryIntent.swift
//  FitLog
//
//  Ask Siri / Shortcuts for today's readiness without opening the app.
//  Reads the existing widget snapshot — does not change freemium rules.
//

import AppIntents
import Foundation

struct ReadinessQueryIntent: AppIntent {
    static var title: LocalizedStringResource = "Readiness"
    static var description = IntentDescription(
        "Hear today's readiness score in Workout Log AI"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let message = RubyAskFitLog.readinessDialog(payload: WidgetSnapshotStore.read())
        return .result(value: message, dialog: IntentDialog(stringLiteral: message))
    }
}
