//
//  CardioQuickAddTemplates.swift
//  FitLog
//
//  Short cardio presets for ad-hoc logging during an active session.
//

import Foundation

struct CardioQuickAddTemplate: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let systemImage: String
    let prescription: CardioPrescription
    /// Preferred seed exercise name; falls back to activity kind.
    let preferredExerciseName: String?
    let fallbackActivityKind: CardioActivityKind

    static let all: [CardioQuickAddTemplate] = [
        CardioQuickAddTemplate(
            id: "zone2-10",
            name: "Zone 2 · 10 min",
            subtitle: "Easy aerobic",
            systemImage: "figure.run",
            prescription: CardioPrescription(
                kind: .steadyState,
                targetDurationSec: 10 * 60,
                targetZone: .zone2
            ),
            preferredExerciseName: "Treadmill Run",
            fallbackActivityKind: .run
        ),
        CardioQuickAddTemplate(
            id: "hiit-15",
            name: "HIIT · 15 min",
            subtitle: "6× 30s / 30s",
            systemImage: "bolt.heart.fill",
            prescription: CardioPrescription(
                kind: .intervals,
                intervals: [
                    CardioIntervalSpec(
                        workDurationSec: 30,
                        restDurationSec: 30,
                        targetZone: .zone4,
                        repeatCount: 6
                    )
                ]
            ),
            preferredExerciseName: "Treadmill Run",
            fallbackActivityKind: .run
        ),
        CardioQuickAddTemplate(
            id: "cooldown-5",
            name: "Cooldown · 5 min",
            subtitle: "Light walk",
            systemImage: "figure.walk",
            prescription: CardioPrescription(
                kind: .steadyState,
                targetDurationSec: 5 * 60,
                targetZone: .zone1
            ),
            preferredExerciseName: "Outdoor Walk",
            fallbackActivityKind: .walk
        )
    ]

    func resolveExercise(in library: [Exercise]) -> Exercise? {
        let cardio = library.filter { $0.modality == .cardio || $0.modality == .hybrid }
        if let name = preferredExerciseName,
           let exact = cardio.first(where: { $0.name == name }) {
            return exact
        }
        return cardio.first { $0.cardioMetadata?.activityKind == fallbackActivityKind }
            ?? cardio.first
    }
}
