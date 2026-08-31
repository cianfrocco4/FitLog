//
//  MuscleGroupLastSessionCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct MuscleGroupLastSessionCopyTests {

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12))!

    @Test func latest_picksMostRecentSessionForMuscleAndSkipsWarmups() {
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest])
        let row = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let older = makeSession(
            name: "Push older",
            endOffsetHours: -48,
            log: ExerciseLog(
                id: UUID(),
                workoutExercise: row,
                loggedSets: [
                    LoggedSet(id: UUID(), weight: 135, reps: 8, restTime: 90, timestamp: now.addingTimeInterval(-172_800))
                ]
            )
        )
        let warmup = LoggedSet(
            id: UUID(),
            weight: 95,
            reps: 10,
            restTime: 60,
            timestamp: now.addingTimeInterval(-3_600),
            isWarmup: true
        )
        let working = LoggedSet(
            id: UUID(),
            weight: 185,
            reps: 8,
            restTime: 90,
            timestamp: now.addingTimeInterval(-3_000)
        )
        let newer = makeSession(
            name: "Push A",
            endOffsetHours: -2,
            log: ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: [warmup, working])
        )
        let latest = MuscleGroupLastSessionCopy.latest(
            muscleGroupName: MuscleGroup.chest.rawValue,
            in: [older, newer],
            resolve: { snap in snap.exerciseId == bench.id ? bench : nil }
        )
        #expect(latest?.session.id == newer.id)
        let recap = MuscleGroupLastSessionCopy.recap(
            session: newer,
            logs: latest!.logs,
            unit: .pounds,
            now: now
        )
        #expect(recap?.contains("185") == true)
        #expect(recap?.contains("Push A") == true)
        #expect(recap?.contains("Today") == true)
        #expect(recap?.contains("95") != true)
    }

    @Test func exploreLine_ignoresOtherMuscles() {
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest])
        let row = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let session = makeSession(
            name: "Push A",
            endOffsetHours: -2,
            log: ExerciseLog(
                id: UUID(),
                workoutExercise: row,
                loggedSets: [
                    LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: now)
                ]
            )
        )
        let resolve: (ExerciseSnapshot) -> Exercise? = { snap in
            snap.exerciseId == bench.id ? bench : nil
        }
        #expect(
            MuscleGroupLastSessionCopy.exploreLine(
                muscleGroupName: MuscleGroup.chest.rawValue,
                sessions: [session],
                unit: .pounds,
                resolve: resolve
            )?.contains("185") == true
        )
        #expect(
            MuscleGroupLastSessionCopy.exploreLine(
                muscleGroupName: MuscleGroup.lats.rawValue,
                sessions: [session],
                unit: .pounds,
                resolve: resolve
            ) == nil
        )
    }

    private func makeSession(name: String, endOffsetHours: Int, log: ExerciseLog) -> WorkoutSession {
        let end = now.addingTimeInterval(TimeInterval(endOffsetHours) * 3600)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: name, exercises: [log.workoutExercise]),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: [log]
        )
    }
}
