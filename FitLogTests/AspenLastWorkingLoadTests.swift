//
//  AspenLastWorkingLoadTests.swift
//  FitLogTests
//

import Testing
import Foundation
@testable import FitLog

struct AspenLastWorkingLoadTests {
    @Test func strengthCaptionUsesNewestWorkingSetAndSkipsWarmup() {
        let exerciseId = UUID()
        let older = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 10,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        let newer = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 95,
                    reps: 8,
                    restTime: 60,
                    timestamp: Date(),
                    setType: .warmup
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 8,
                    restTime: 90,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )

        let caption = AspenLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 185 lb × 8 reps")
    }

    @Test func cardioCaptionUsesNewestDurationAndSkipsIntervalRest() {
        let exerciseId = UUID()
        let older = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 20 * 60, source: .manual)
                )
            ]
        )
        let newer = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .intervalRest,
                    cardioMetrics: CardioMetrics(durationSec: 30, source: .timer)
                ),
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )

        let caption = AspenLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
        #expect(
            AspenLastWorkingLoad.lastCardioDurationSec(for: exerciseId, from: [older, newer])
                == 45 * 60
        )
    }

    @Test func inProgressSessionIsIgnored() {
        let exerciseId = UUID()
        let open = session(
            endedAt: nil,
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 225,
                    reps: 5,
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            AspenLastWorkingLoad.caption(
                for: exerciseId,
                from: [open],
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func applyingLastDurationFillsTargetSeconds() {
        let original = CardioPrescription(
            kind: .steadyState,
            targetDurationSec: 20 * 60,
            targetZone: .zone2
        )
        let updated = AspenLastWorkingLoad.applyingLastDuration(45 * 60, to: original)
        #expect(updated.targetDurationSec == 45 * 60)
        #expect(updated.kind == .steadyState)
        #expect(updated.targetZone == .zone2)
    }

    @Test func prescriptionFillingLastDurationKeepsDistanceDefaultWhenNoHistory() {
        let exercise = Exercise(
            id: UUID(),
            name: "Easy run",
            description: "",
            targetedMuscles: [],
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(
                activityKind: .run,
                primaryMetric: .distance,
                equipment: .outdoor,
                estimatedMETs: nil,
                supportsIntervals: false
            )
        )
        let rx = AspenLastWorkingLoad.prescriptionFillingLastDuration(for: exercise, from: [])
        #expect(rx.kind == .steadyState)
        #expect(rx.targetDurationSec == 20 * 60)
        #expect(rx.targetDistanceM == 3_000)
    }

    @Test func prescriptionFillingLastDurationUsesNewestCompletedMinutes() {
        let exerciseId = UUID()
        let exercise = Exercise(
            id: exerciseId,
            name: "Zone 2",
            description: "",
            targetedMuscles: [],
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(
                activityKind: .run,
                primaryMetric: .time,
                equipment: .outdoor,
                estimatedMETs: nil,
                supportsIntervals: false
            )
        )
        let older = session(
            endedAt: Date().addingTimeInterval(-86_400),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 20 * 60, source: .manual)
                )
            ]
        )
        let newer = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: Date(),
                    setType: .steadyState,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, source: .timer)
                )
            ]
        )
        let rx = AspenLastWorkingLoad.prescriptionFillingLastDuration(
            for: exercise,
            from: [older, newer]
        )
        #expect(rx.targetDurationSec == 45 * 60)
        #expect(rx.targetZone == .zone2)
    }

    @Test func captionsByExerciseIdIndexesMultipleExercises() {
        let bench = UUID()
        let run = UUID()
        let sessions = [
            session(
                endedAt: Date(),
                exerciseId: bench,
                sets: [
                    LoggedSet(
                        id: UUID(),
                        weight: 185,
                        reps: 8,
                        restTime: 90,
                        timestamp: Date(),
                        setType: .working
                    )
                ]
            ),
            session(
                endedAt: Date().addingTimeInterval(-3_600),
                exerciseId: run,
                sets: [
                    LoggedSet(
                        id: UUID(),
                        weight: 0,
                        reps: 0,
                        restTime: 0,
                        timestamp: Date(),
                        setType: .steadyState,
                        cardioMetrics: CardioMetrics(durationSec: 30 * 60, source: .manual)
                    )
                ]
            )
        ]
        let map = AspenLastWorkingLoad.captionsByExerciseId(from: sessions, displayUnit: .pounds)
        #expect(map[bench] == "Last 185 lb × 8 reps")
        #expect(map[run] == "Last 30:00")
    }

    private func session(
        endedAt: Date?,
        exerciseId: UUID,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Move")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let start = (endedAt ?? Date()).addingTimeInterval(-3_600)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Test", exercises: [row]),
            startTime: start,
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)]
        )
    }
}
