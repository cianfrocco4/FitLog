//
//  LastSessionWorkingRecapTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct LastSessionWorkingRecapTests {
    @Test func skipsWarmupsAndUsesLastWorkingSet() {
        let warmup = LoggedSet(id: UUID(), weight: 45, reps: 10, restTime: 60, timestamp: Date(), setType: .warmup)
        let first = LoggedSet(id: UUID(), weight: 135, reps: 8, restTime: 90, timestamp: Date(), setType: .working)
        let last = LoggedSet(id: UUID(), weight: 185, reps: 5, restTime: 90, timestamp: Date(), setType: .working)
        let session = makeSession(
            kind: .strength,
            logs: [makeLog(name: "Bench Press", sets: [warmup, first, last])]
        )
        let recap = LastSessionWorkingRecap.make(from: session, weightUnit: .pounds)
        #expect(recap?.compactLine == "185 lb × 5 reps")
        #expect(recap?.detailLine == "Bench Press · 185 lb × 5 reps")
        #expect(recap?.durationLine == "45 min")
    }

    @Test func cardioUsesLoggedDurationWhenNoWorkingLoad() {
        let cardio = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 45 * 60)
        )
        let session = makeSession(
            kind: .cardio,
            logs: [makeLog(name: "Zone 2", sets: [cardio])]
        )
        let recap = LastSessionWorkingRecap.make(from: session, weightUnit: .pounds)
        #expect(recap?.compactLine == "45:00")
        #expect(recap?.durationLine == "45 min")
    }

    @Test func prefersWorkingLoadOverCardioOnHybrid() {
        let working = LoggedSet(id: UUID(), weight: 225, reps: 3, restTime: 180, timestamp: Date(), setType: .working)
        let cardio = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 600)
        )
        let session = makeSession(
            kind: .hybrid,
            logs: [
                makeLog(name: "Squat", sets: [working]),
                makeLog(name: "Bike", sets: [cardio])
            ]
        )
        let recap = LastSessionWorkingRecap.make(from: session, weightUnit: .pounds)
        #expect(recap?.compactLine == "225 lb × 3 reps")
        #expect(recap?.detailLine == "Squat · 225 lb × 3 reps")
    }

    @Test func compactLineIsNilForInProgressSession() {
        let working = LoggedSet(id: UUID(), weight: 100, reps: 8, restTime: 90, timestamp: Date(), setType: .working)
        var session = makeSession(kind: .strength, logs: [makeLog(name: "Row", sets: [working])])
        session.endTime = nil
        #expect(LastSessionWorkingRecap.compactLine(from: session, weightUnit: .pounds) == nil)
    }

    private func makeLog(name: String, sets: [LoggedSet]) -> ExerciseLog {
        let exercise = Exercise(id: UUID(), name: name, description: "", targetedMuscles: [.chest])
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "8")
        return ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: sets)
    }

    private func makeSession(kind: WorkoutKind, logs: [ExerciseLog]) -> WorkoutSession {
        let ended = Date(timeIntervalSince1970: 1_700_000_000)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Session", exercises: logs.map(\.workoutExercise), workoutKind: kind),
            startTime: ended.addingTimeInterval(-45 * 60),
            endTime: ended,
            exerciseLogs: logs
        )
    }
}
