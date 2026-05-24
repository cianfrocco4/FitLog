//
//  CardioViewsPreviews.swift
//  FitLog
//
//  SwiftUI previews for cardio surfaces (light + dark).
//

import SwiftUI

#if DEBUG
private enum CardioPreviewFixtures {
    static let steadyPrescription = CardioPrescription(
        kind: .steadyState,
        targetDurationSec: 45 * 60,
        targetDistanceM: 8000,
        targetZone: .zone2
    )

    static let intervalPrescription = CardioPrescription(
        kind: .intervals,
        intervals: [
            CardioIntervalSpec(workDurationSec: 180, restDurationSec: 90, repeatCount: 6)
        ]
    )

    static let sampleExercise = Exercise(
        id: UUID(),
        name: "Treadmill Run",
        description: "Indoor run",
        targetedMuscles: [.other],
        modality: .cardio,
        cardioMetadata: CardioExerciseMetadata(activityKind: .run, primaryMetric: .distance, equipment: .treadmill)
    )

    static let loggedIntervals: [LoggedSet] = [
        LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .intervalWork,
            cardioMetrics: CardioMetrics(durationSec: 180, distanceM: 800, source: .timer)
        ),
        LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date().addingTimeInterval(200),
            setType: .intervalRest,
            cardioMetrics: CardioMetrics(durationSec: 90, source: .timer)
        )
    ]
}

#Preview("Prescription row — light") {
    CardioPrescriptionRowView(
        prescription: CardioPreviewFixtures.steadyPrescription,
        exercise: CardioPreviewFixtures.sampleExercise
    )
    .padding()
}

#Preview("Prescription row — dark") {
    CardioPrescriptionRowView(
        prescription: CardioPreviewFixtures.intervalPrescription,
        exercise: CardioPreviewFixtures.sampleExercise
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Live metrics strip") {
    CardioLiveMetricsStrip(
        elapsedSeconds: 754,
        phaseLabel: "Work",
        roundLabel: "Round 2 of 6",
        isPaused: false
    )
    .padding()
}

#Preview("Interval timeline") {
    CardioIntervalTimelineView(loggedSets: CardioPreviewFixtures.loggedIntervals)
        .padding()
}

#Preview("Completion rings") {
    CardioCompletionRingView(
        durationSeconds: 2820,
        distanceMeters: 8500,
        durationGoalSeconds: 3600,
        distanceGoalMeters: 10_000
    )
    .padding()
}

#Preview("Completion rings — dark") {
    CardioCompletionRingView(
        durationSeconds: 900,
        distanceMeters: 0,
        durationGoalSeconds: nil,
        distanceGoalMeters: nil
    )
    .padding()
    .preferredColorScheme(.dark)
}
#endif
