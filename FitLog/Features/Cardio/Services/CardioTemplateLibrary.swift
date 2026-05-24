//
//  CardioTemplateLibrary.swift
//  FitLog
//
//  Built-in cardio workout templates for the builder and new-workout flow.
//

import Foundation

enum CardioTemplateLibrary {

    static let all: [CardioWorkoutTemplate] = [
        zone2FortyFive,
        fiveKProgression,
        hiitThirtyThirty,
        tempoTwenty,
        rowingTwoK,
        hybridRunAndRow,
    ]

    /// Horizontal quick-start cards in `NewWorkoutSheet`.
    static let quickStart: [CardioWorkoutTemplate] = [
        zone2FortyFive,
        hiitThirtyThirty,
        fiveKProgression,
    ]

    static func template(id: String) -> CardioWorkoutTemplate? {
        all.first { $0.id == id }
    }

    // MARK: - Templates

    /// Zone 2 treadmill — 45 minutes steady.
    static let zone2FortyFive = CardioWorkoutTemplate(
        id: "zone2-45",
        name: "Zone 2 · 45 min",
        subtitle: "Easy aerobic treadmill block",
        rows: [
            CardioTemplateRowSpec(
                seedIndex: 4,
                prescription: CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 45 * 60,
                    targetZone: .zone2,
                    notes: "Conversational pace; nasal breathing when possible."
                )
            ),
        ]
    )

    /// 5K-style outdoor run with distance target.
    static let fiveKProgression = CardioWorkoutTemplate(
        id: "5k-progression",
        name: "5K Run",
        subtitle: "Outdoor distance focus",
        rows: [
            CardioTemplateRowSpec(
                seedIndex: 13,
                prescription: CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 28 * 60,
                    targetDistanceM: 5_000,
                    targetPaceSecPerKm: 330,
                    targetZone: .zone3,
                    notes: "Warm up 5–10 min before the main block."
                )
            ),
        ]
    )

    /// 30s on / 30s off × 10 on treadmill.
    static let hiitThirtyThirty = CardioWorkoutTemplate(
        id: "hiit-30-30",
        name: "30/30 HIIT",
        subtitle: "10 rounds · treadmill",
        rows: [
            CardioTemplateRowSpec(
                seedIndex: 4,
                prescription: CardioPrescription(
                    kind: .intervals,
                    intervals: [
                        CardioIntervalSpec(
                            workDurationSec: 30,
                            restDurationSec: 30,
                            targetZone: .zone4,
                            repeatCount: 10
                        ),
                    ],
                    notes: "Increase speed on work intervals; walk or slow jog on rest."
                )
            ),
        ]
    )

    /// 20-minute tempo outdoor run.
    static let tempoTwenty = CardioWorkoutTemplate(
        id: "tempo-20",
        name: "Tempo 20",
        subtitle: "Threshold outdoor run",
        rows: [
            CardioTemplateRowSpec(
                seedIndex: 2,
                prescription: CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 20 * 60,
                    targetZone: .zone3,
                    notes: "Comfortably hard — controlled breathing."
                )
            ),
        ]
    )

    /// 2K row erg test / training piece.
    static let rowingTwoK = CardioWorkoutTemplate(
        id: "row-2k",
        name: "Row 2K",
        subtitle: "Single-piece erg",
        rows: [
            CardioTemplateRowSpec(
                seedIndex: 23,
                prescription: CardioPrescription(
                    kind: .steadyState,
                    targetDistanceM: 2_000,
                    targetPaceSecPerKm: nil,
                    notes: "Full 2K piece; pace by feel or prior split."
                )
            ),
        ]
    )

    /// Run + row hybrid session.
    static let hybridRunAndRow = CardioWorkoutTemplate(
        id: "hybrid-run-row",
        name: "Run + Row",
        subtitle: "Mixed cardio conditioning",
        workoutKind: .hybrid,
        rows: [
            CardioTemplateRowSpec(
                seedIndex: 1,
                prescription: CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 15 * 60,
                    targetZone: .zone2
                )
            ),
            CardioTemplateRowSpec(
                seedIndex: 22,
                prescription: CardioPrescription(
                    kind: .steadyState,
                    targetDurationSec: 10 * 60,
                    targetZone: .zone3
                )
            ),
        ]
    )

    /// Resolves seed rows against the live exercise library (seed UUIDs first, then name fallback).
    @MainActor
    static func resolveRows(
        _ specs: [CardioTemplateRowSpec],
        library: [Exercise]
    ) -> [(exercise: Exercise, prescription: CardioPrescription)] {
        specs.compactMap { spec in
            guard let exercise = CardioExerciseSeed.exercise(seedIndex: spec.seedIndex, library: library) else {
                return nil
            }
            return (exercise, spec.prescription)
        }
    }
}
