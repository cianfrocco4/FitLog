//
//  OakLastWorkingLoadTests.swift
//  FitLogTests
//

import Testing
import Foundation
@testable import FitLog

struct OakLastWorkingLoadTests {
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

        let caption = OakLastWorkingLoad.caption(
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

        let caption = OakLastWorkingLoad.caption(
            for: exerciseId,
            from: [older, newer],
            displayUnit: .pounds
        )
        #expect(caption == "Last 45:00")
        #expect(
            OakLastWorkingLoad.lastCardioDurationSec(for: exerciseId, from: [older, newer])
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
            OakLastWorkingLoad.caption(
                for: exerciseId,
                from: [open],
                displayUnit: .pounds
            ) == nil
        )
    }

    @Test func workoutExerciseCaptionUsesResolvedExerciseId() {
        let exerciseId = UUID()
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: exerciseId, nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let logged = session(
            endedAt: Date(),
            exerciseId: exerciseId,
            sets: [
                LoggedSet(
                    id: UUID(),
                    weight: 185,
                    reps: 5,
                    restTime: 120,
                    timestamp: Date(),
                    setType: .working
                )
            ]
        )
        #expect(
            OakLastWorkingLoad.caption(
                for: row,
                from: [logged],
                displayUnit: .pounds
            ) == "Last 185 lb × 5 reps"
        )
    }

    @Test func applyingLastDurationFillsTargetSeconds() {
        let original = CardioPrescription(
            kind: .steadyState,
            targetDurationSec: 10 * 60,
            targetZone: .zone2
        )
        let updated = OakLastWorkingLoad.applyingLastDuration(45 * 60, to: original)
        #expect(updated.targetDurationSec == 45 * 60)
        #expect(updated.kind == .steadyState)
        #expect(updated.targetZone == .zone2)
    }

    @Test func finisherPrescriptionKeepsTemplateWhenNoHistory() {
        let exercise = Exercise(
            id: UUID(),
            name: "Treadmill Run",
            description: "",
            targetedMuscles: [],
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(
                activityKind: .run,
                primaryMetric: .time,
                equipment: .treadmill,
                estimatedMETs: nil,
                supportsIntervals: false
            )
        )
        let template = CardioQuickAddTemplate.all[0]
        let rx = OakLastWorkingLoad.finisherPrescription(
            from: template,
            exercise: exercise,
            sessions: []
        )
        #expect(rx.targetDurationSec == 10 * 60)
        #expect(rx.targetZone == .zone2)
        #expect(
            OakLastWorkingLoad.finisherQuickLabel(
                template: template,
                exercise: exercise,
                sessions: []
            ) == "Quick 10 min"
        )
        #expect(
            OakLastWorkingLoad.finisherQuickHint(label: "Quick 10 min")
                == "Adds a 10 minute zone 2 cardio exercise to this workout."
        )
    }

    @Test func finisherPrescriptionUsesNewestCompletedMinutes() {
        let exerciseId = UUID()
        let exercise = Exercise(
            id: exerciseId,
            name: "Treadmill Run",
            description: "",
            targetedMuscles: [],
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(
                activityKind: .run,
                primaryMetric: .time,
                equipment: .treadmill,
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
        let template = CardioQuickAddTemplate.all[0]
        let rx = OakLastWorkingLoad.finisherPrescription(
            from: template,
            exercise: exercise,
            sessions: [older, newer]
        )
        #expect(rx.targetDurationSec == 45 * 60)
        #expect(rx.targetZone == .zone2)
        #expect(
            OakLastWorkingLoad.finisherQuickLabel(
                template: template,
                exercise: exercise,
                sessions: [older, newer]
            ) == "Use last time (45:00)"
        )
        #expect(
            OakLastWorkingLoad.finisherQuickHint(label: "Use last time (45:00)")
                == "Adds a zone 2 cardio exercise using your last logged duration. You can edit before logging."
        )
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
        let map = OakLastWorkingLoad.captionsByExerciseId(from: sessions, displayUnit: .pounds)
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
