//
//  TrainingLoadMetricsTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct TrainingLoadMetricsTests {

    @Test @MainActor func trainingLoadMetrics_excludesWarmupSets() throws {
        let container = try makeInMemoryContainer()
        let dataVM = DataManager(modelContainer: container)
        let now = Date()
        dataVM.completedSessions = [
            makeSession(
                endedAt: now.addingTimeInterval(-3600),
                sets: [
                    (reps: 10, warmup: true),
                    (reps: 8, warmup: false),
                    (reps: 6, warmup: false)
                ]
            )
        ]

        let metrics = dataVM.trainingLoadMetrics(now: now)
        #expect(metrics.recentHardSets == 2)
    }

    @Test @MainActor func trainingLoadMetrics_ignoresSessionsOutside72hWindow() throws {
        let container = try makeInMemoryContainer()
        let dataVM = DataManager(modelContainer: container)
        let now = Date()
        dataVM.completedSessions = [
            makeSession(
                endedAt: now.addingTimeInterval(-(73 * 3600)),
                sets: [(reps: 10, warmup: false)]
            ),
            makeSession(
                endedAt: now.addingTimeInterval(-(24 * 3600)),
                sets: [(reps: 5, warmup: false), (reps: 5, warmup: false)]
            )
        ]

        let metrics = dataVM.trainingLoadMetrics(now: now)
        #expect(metrics.recentHardSets == 2)
    }

    @Test @MainActor func trainingLoadMetrics_baselineUses28DayAverage() throws {
        let container = try makeInMemoryContainer()
        let dataVM = DataManager(modelContainer: container)
        let now = Date()
        dataVM.completedSessions = (0..<7).map { dayOffset in
            makeSession(
                endedAt: now.addingTimeInterval(-Double(dayOffset * 24 * 3600)),
                sets: Array(repeating: (reps: 4, warmup: false), count: 3)
            )
        }

        let metrics = dataVM.trainingLoadMetrics(now: now)
        #expect(metrics.typicalHardSets72h >= 6)
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeSession(
        endedAt: Date,
        sets: [(reps: Int, warmup: Bool)]
    ) -> WorkoutSession {
        let workout = Workout(id: UUID(), name: "Test", exercises: [])
        let loggedSets = sets.map { spec in
            LoggedSet(
                id: UUID(),
                weight: 100,
                reps: spec.reps,
                restTime: 90,
                timestamp: endedAt,
                setType: spec.warmup ? .warmup : .working
            )
        }
        let exercise = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Bench")),
            defaultRestTime: 90,
            recommendedSets: 3,
            recommendedReps: "8"
        )
        return WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: endedAt.addingTimeInterval(-3600),
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: exercise, loggedSets: loggedSets)]
        )
    }
}
