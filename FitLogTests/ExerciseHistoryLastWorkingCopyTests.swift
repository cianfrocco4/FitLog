//
//  ExerciseHistoryLastWorkingCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ExerciseHistoryLastWorkingCopyTests {

    private let benchId = UUID()
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    @Test func lastWorkingSet_nilWhenOnlyWarmUps() {
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: makeBenchRow(),
            loggedSets: [makeSet(weight: 45, reps: 10, timestamp: Date(), type: .warmup)]
        )
        #expect(ExerciseHistoryLastWorkingCopy.lastWorkingSet(in: log) == nil)
        #expect(ExerciseHistoryLastWorkingCopy.lastWorkingLine(for: log, unit: .pounds) == nil)
    }

    @Test func lastWorkingSet_skipsWarmUpAndPicksLatestTimestamp() {
        let warm = makeSet(weight: 45, reps: 10, timestamp: Date(timeIntervalSince1970: 100), type: .warmup)
        let first = makeSet(weight: 135, reps: 8, timestamp: Date(timeIntervalSince1970: 200), type: .working)
        let later = makeSet(weight: 185, reps: 5, timestamp: Date(timeIntervalSince1970: 300), type: .working)
        let log = ExerciseLog(id: UUID(), workoutExercise: makeBenchRow(), loggedSets: [later, warm, first])
        let last = ExerciseHistoryLastWorkingCopy.lastWorkingSet(in: log)
        #expect(last?.weight == 185)
        #expect(last?.reps == 5)
    }

    @Test func lastWorkingLine_strengthUsesDisplayUnit() {
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: makeBenchRow(),
            loggedSets: [makeSet(weight: 185, reps: 8, timestamp: Date(), type: .working)]
        )
        let line = ExerciseHistoryLastWorkingCopy.lastWorkingLine(for: log, unit: .pounds)
        #expect(line == "Last working: 185 lb × 8 reps")
    }

    @Test func lastWorkingLine_cardioUsesDurationSummary() {
        let cardio = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: Date(),
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: 2700, source: .manual)
        )
        let log = ExerciseLog(id: UUID(), workoutExercise: makeBenchRow(), loggedSets: [cardio])
        let line = ExerciseHistoryLastWorkingCopy.lastWorkingLine(for: log, unit: .pounds)
        #expect(line?.contains("Last working:") == true)
        #expect(line?.contains("45:00") == true)
    }

    @Test func relativeDayLabel_todayYesterdayAndOlder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(
            ExerciseHistoryLastWorkingCopy.relativeDayLabel(
                endingAt: now,
                now: now,
                calendar: calendar
            ) == "Today"
        )
        #expect(
            ExerciseHistoryLastWorkingCopy.relativeDayLabel(
                endingAt: now.addingTimeInterval(-24 * 3600),
                now: now,
                calendar: calendar
            ) == "Yesterday"
        )
        #expect(
            ExerciseHistoryLastWorkingCopy.relativeDayLabel(
                endingAt: now.addingTimeInterval(-5 * 24 * 3600),
                now: now,
                calendar: calendar
            ) == "5d ago"
        )
    }

    @Test func recap_includesWorkoutNameAndRelativeDay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let end = now.addingTimeInterval(-2 * 24 * 3600)
        let session = makeSession(endedAt: end, workoutName: "Push A", sets: [
            makeSet(weight: 185, reps: 8, timestamp: end, type: .working)
        ])
        let recap = ExerciseHistoryLastWorkingCopy.recap(
            session: session,
            log: session.exerciseLogs[0],
            unit: .pounds,
            now: now,
            calendar: calendar
        )
        #expect(recap == "Last working: 185 lb × 8 reps · Push A · 2d ago")
    }

    @Test func exploreLine_usesLatestCompletedSessionForExercise() {
        let olderEnd = Date(timeIntervalSince1970: 1_700_000_000)
        let newerEnd = Date(timeIntervalSince1970: 1_700_200_000)
        let older = makeSession(endedAt: olderEnd, workoutName: "Push A", sets: [
            makeSet(weight: 135, reps: 8, timestamp: olderEnd, type: .working)
        ])
        let newer = makeSession(endedAt: newerEnd, workoutName: "Push B", sets: [
            makeSet(weight: 185, reps: 6, timestamp: newerEnd, type: .working)
        ])
        let line = ExerciseHistoryLastWorkingCopy.exploreLine(
            exerciseId: benchId,
            sessions: [older, newer],
            unit: .pounds
        )
        #expect(line == "Last working: 185 lb × 6 reps")
    }

    @Test func exploreLine_ignoresOtherExercises() {
        let other = Exercise(id: UUID(), name: "Squat", description: "", targetedMuscles: [.quads], isCustom: false)
        let we = WorkoutExercise(id: UUID(), exercise: other, recommendedSets: 3, recommendedReps: "5")
        let end = Date()
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Legs", exercises: [we]),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [
                makeSet(weight: 225, reps: 5, timestamp: end, type: .working)
            ])]
        )
        let line = ExerciseHistoryLastWorkingCopy.exploreLine(
            exerciseId: benchId,
            sessions: [session],
            unit: .pounds
        )
        #expect(line == nil)
    }

    private func makeBenchRow() -> WorkoutExercise {
        let exercise = Exercise(
            id: benchId,
            name: "Bench Press",
            description: "",
            targetedMuscles: [.chest],
            isCustom: false
        )
        return WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "8")
    }

    private func makeSet(weight: Double, reps: Int, timestamp: Date, type: ExerciseSetType) -> LoggedSet {
        LoggedSet(
            id: UUID(),
            weight: weight,
            reps: reps,
            restTime: 90,
            timestamp: timestamp,
            setType: type
        )
    }

    private func makeSession(endedAt: Date, workoutName: String, sets: [LoggedSet]) -> WorkoutSession {
        let we = makeBenchRow()
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: workoutName, exercises: [we]),
            startTime: endedAt.addingTimeInterval(-3600),
            endTime: endedAt,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: sets)]
        )
    }
}
