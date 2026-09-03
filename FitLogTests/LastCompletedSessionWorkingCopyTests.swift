//
//  LastCompletedSessionWorkingCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct LastCompletedSessionWorkingCopyTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    @Test func skipsWarmupsForLastWorkingLoad() {
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = strengthSession(
            libraryId: UUID(),
            name: "Push A",
            end: end,
            start: end.addingTimeInterval(-3600),
            exerciseName: "Bench Press",
            sets: [
                LoggedSet(id: UUID(), weight: 95, reps: 8, restTime: 60, timestamp: end, setType: .warmup),
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: end, setType: .working)
            ]
        )
        let recap = LastCompletedSessionWorkingCopy.recap(
            from: session,
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.workoutName == "Push A")
        #expect(recap?.lastDoneLine == "Last done today")
        #expect(recap?.loadLine.contains("185") == true)
        #expect(recap?.loadLine.contains("95") == false)
        #expect(recap?.exerciseName == "Bench Press")
    }

    @Test func cardioUsesDurationSummary() {
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: end)!
        let session = cardioSession(
            libraryId: UUID(),
            name: "Zone 2",
            end: yesterday,
            start: yesterday.addingTimeInterval(-45 * 60),
            durationSec: 45 * 60
        )
        let recap = LastCompletedSessionWorkingCopy.recap(
            from: session,
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.lastDoneLine == "Last done yesterday")
        #expect(recap?.loadLine.contains("45") == true)
        #expect(recap?.exerciseName == nil)
    }

    @Test func latestCompletedSessionPicksNewestEndTime() {
        let olderEnd = Date(timeIntervalSince1970: 1_725_000_000)
        let newerEnd = olderEnd.addingTimeInterval(8_000)
        let older = strengthSession(
            libraryId: UUID(),
            name: "Pull A",
            end: olderEnd,
            start: olderEnd.addingTimeInterval(-1800),
            exerciseName: "Row",
            sets: [LoggedSet(id: UUID(), weight: 135, reps: 10, restTime: 90, timestamp: olderEnd, setType: .working)]
        )
        let newer = strengthSession(
            libraryId: UUID(),
            name: "Legs A",
            end: newerEnd,
            start: newerEnd.addingTimeInterval(-1800),
            exerciseName: "Squat",
            sets: [LoggedSet(id: UUID(), weight: 225, reps: 5, restTime: 180, timestamp: newerEnd, setType: .working)]
        )
        let latest = LastCompletedSessionWorkingCopy.latestCompletedSession(in: [older, newer])
        #expect(latest?.workout.name == "Legs A")
    }

    @Test func recapForExerciseIdUsesThatMovementsLastWorkingSet() {
        let benchId = UUID()
        let rowId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let bench = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: benchId, nameAtTimeOfLog: "Bench Press")),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: rowId, nameAtTimeOfLog: "Barbell Row")),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Upper", exercises: [bench, row]),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: bench,
                    loggedSets: [
                        LoggedSet(id: UUID(), weight: 45, reps: 10, restTime: 60, timestamp: end, setType: .warmup),
                        LoggedSet(id: UUID(), weight: 185, reps: 5, restTime: 90, timestamp: end, setType: .working)
                    ]
                ),
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: row,
                    loggedSets: [
                        LoggedSet(id: UUID(), weight: 155, reps: 8, restTime: 90, timestamp: end, setType: .working)
                    ]
                )
            ],
            sessionPlanOrigin: .workout(UUID())
        )
        let recap = LastCompletedSessionWorkingCopy.recap(
            forExerciseId: benchId,
            sessions: [session],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.exerciseName == "Bench Press")
        #expect(recap?.loadLine.contains("185") == true)
        #expect(recap?.loadLine.contains("155") == false)
    }

    @Test func sourceWorkout_prefersLibraryMatchFromPlanOrigin() {
        let libraryId = UUID()
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest], isCustom: false)
        let libraryRow = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 4, recommendedReps: "8")
        let library = Workout(id: libraryId, name: "Push A", exercises: [libraryRow])
        let sessionRow = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A (session)", exercises: [sessionRow]),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(libraryId)
        )
        let source = LastCompletedSessionWorkingCopy.sourceWorkout(session: session, library: [library])
        #expect(source?.id == libraryId)
        #expect(source?.exercises.first?.recommendedSets == 4)
    }

    @Test func sourceWorkout_fallsBackToSessionWorkoutWhenLibraryMissing() {
        let bench = Exercise(id: UUID(), name: "Bench", description: "", targetedMuscles: [.chest], isCustom: false)
        let row = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let sessionWorkout = Workout(id: UUID(), name: "Ad hoc", exercises: [row])
        let session = WorkoutSession(
            id: UUID(),
            workout: sessionWorkout,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            exerciseLogs: [],
            sessionPlanOrigin: .workout(UUID())
        )
        let source = LastCompletedSessionWorkingCopy.sourceWorkout(session: session, library: [])
        #expect(source?.id == sessionWorkout.id)
    }

    @Test func sourceWorkout_nilWhenNoExercises() {
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Empty", exercises: []),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            exerciseLogs: []
        )
        #expect(LastCompletedSessionWorkingCopy.sourceWorkout(session: session, library: []) == nil)
    }

    @Test func libraryWorkoutToStart_usesPlanOriginThenLibraryContainingExercise() {
        let benchId = UUID()
        let libraryId = UUID()
        let bench = Exercise(id: benchId, name: "Bench", description: "", targetedMuscles: [.chest], isCustom: false)
        let libraryRow = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 4, recommendedReps: "8")
        let library = Workout(id: libraryId, name: "Push A", exercises: [libraryRow])
        let end = Date()
        let sessionRow = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: benchId, nameAtTimeOfLog: "Bench")),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Scratch", exercises: [sessionRow]),
            startTime: end.addingTimeInterval(-1800),
            endTime: end,
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: sessionRow,
                    loggedSets: [LoggedSet(id: UUID(), weight: 135, reps: 8, restTime: 90, timestamp: end, setType: .working)]
                )
            ],
            sessionPlanOrigin: .workout(libraryId)
        )
        let match = LastCompletedSessionWorkingCopy.libraryWorkoutToStart(
            forExerciseId: benchId,
            library: [library],
            sessions: [session]
        )
        #expect(match?.id == libraryId)
    }

    private func strengthSession(
        libraryId: UUID,
        name: String,
        end: Date,
        start: Date,
        exerciseName: String,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: exerciseName)),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: name, exercises: [row]),
            startTime: start,
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)],
            sessionPlanOrigin: .workout(libraryId)
        )
    }

    private func cardioSession(
        libraryId: UUID,
        name: String,
        end: Date,
        start: Date,
        durationSec: Int
    ) -> WorkoutSession {
        let row = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Zone 2")),
            recommendedSets: 1,
            recommendedReps: "—"
        )
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: end,
            setType: .steadyState,
            cardioMetrics: CardioMetrics(durationSec: durationSec, source: .manual)
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: name, exercises: [row], workoutKind: .cardio),
            startTime: start,
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: [set])],
            sessionPlanOrigin: .workout(libraryId)
        )
    }
}
