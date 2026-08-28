//
//  SessionLastWorkingSetCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct SessionLastWorkingSetCopyTests {
    @Test func line_usesLastWorkingSetNotWarmup() {
        let log = exerciseLog(sets: [
            loggedSet(weight: 135, reps: 8, type: .warmup),
            loggedSet(weight: 185, reps: 8, type: .working),
            loggedSet(weight: 185, reps: 6, type: .working)
        ])
        #expect(
            SessionLastWorkingSetCopy.line(for: log, unit: .pounds)
                == "Last working: 185 lb × 6 reps"
        )
    }

    @Test func line_nilWhenOnlyWarmups() {
        let log = exerciseLog(sets: [
            loggedSet(weight: 95, reps: 10, type: .warmup)
        ])
        #expect(SessionLastWorkingSetCopy.line(for: log, unit: .pounds) == nil)
    }

    @Test func line_cardioUsesDurationSummary() {
        let log = exerciseLog(sets: [
            LoggedSet(
                id: UUID(),
                weight: 0,
                reps: 0,
                restTime: 0,
                timestamp: Date(),
                setType: .steadyState,
                cardioMetrics: CardioMetrics(durationSec: 45 * 60, distanceM: 6000)
            )
        ])
        let line = SessionLastWorkingSetCopy.line(for: log, unit: .pounds)
        #expect(line?.contains("Last working:") == true)
        #expect(line?.contains("6.0 km") == true || line?.contains("km") == true)
    }

    @Test func lastWorkingSet_skipsTrailingWarmup() {
        let log = exerciseLog(sets: [
            loggedSet(weight: 185, reps: 8, type: .working),
            loggedSet(weight: 95, reps: 12, type: .warmup)
        ])
        #expect(SessionLastWorkingSetCopy.lastWorkingSet(in: log)?.weight == 185)
        #expect(SessionLastWorkingSetCopy.lastWorkingSet(in: log)?.reps == 8)
    }

    private func exerciseLog(sets: [LoggedSet]) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        return ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(
                id: UUID(),
                resolution: .concrete(ExerciseSnapshot(from: exercise)),
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8"
            ),
            loggedSets: sets
        )
    }

    private func loggedSet(weight: Double, reps: Int, type: ExerciseSetType) -> LoggedSet {
        LoggedSet(
            id: UUID(),
            weight: weight,
            reps: reps,
            restTime: 90,
            timestamp: Date(),
            setType: type
        )
    }
}
