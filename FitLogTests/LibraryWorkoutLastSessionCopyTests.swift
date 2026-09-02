//
//  LibraryWorkoutLastSessionCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct LibraryWorkoutLastSessionCopyTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    @Test func skipsWarmupsForLastWorkingLoad() {
        let libraryId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = strengthSession(
            libraryId: libraryId,
            end: end,
            start: end.addingTimeInterval(-3600),
            sets: [
                LoggedSet(id: UUID(), weight: 95, reps: 8, restTime: 60, timestamp: end, setType: .warmup),
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: end, setType: .working)
            ]
        )
        let recap = LibraryWorkoutLastSessionCopy.recap(
            forLibraryWorkoutId: libraryId,
            sessions: [session],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.lastDoneLine == "Last done today")
        #expect(recap?.loadLine.contains("185") == true)
        #expect(recap?.loadLine.contains("95") == false)
        #expect(recap?.exerciseName == "Bench Press")
    }

    @Test func cardioUsesDurationSummary() {
        let libraryId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: end)!
        let session = cardioSession(
            libraryId: libraryId,
            end: yesterday,
            start: yesterday.addingTimeInterval(-45 * 60),
            durationSec: 45 * 60
        )
        let recap = LibraryWorkoutLastSessionCopy.recap(
            forLibraryWorkoutId: libraryId,
            sessions: [session],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.lastDoneLine == "Last done yesterday")
        #expect(recap?.loadLine.contains("45") == true)
    }

    @Test func prefersPlanOriginOverUnrelatedSessions() {
        let libraryId = UUID()
        let otherId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let matching = strengthSession(
            libraryId: libraryId,
            end: end.addingTimeInterval(-8_000),
            start: end.addingTimeInterval(-10_000),
            sets: [LoggedSet(id: UUID(), weight: 135, reps: 10, restTime: 90, timestamp: end, setType: .working)]
        )
        let other = strengthSession(
            libraryId: otherId,
            end: end,
            start: end.addingTimeInterval(-1_800),
            sets: [LoggedSet(id: UUID(), weight: 315, reps: 3, restTime: 180, timestamp: end, setType: .working)]
        )
        let recap = LibraryWorkoutLastSessionCopy.recap(
            forLibraryWorkoutId: libraryId,
            sessions: [other, matching],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.loadLine.contains("135") == true)
    }

    @Test func exerciseRecapUsesThatMovement() {
        let squatId = UUID()
        let benchId = UUID()
        let libraryId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let bench = Exercise(id: benchId, name: "Bench Press", description: "", targetedMuscles: [.chest])
        let squat = Exercise(id: squatId, name: "Back Squat", description: "", targetedMuscles: [.quads])
        let benchLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8"),
            loggedSets: [LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: end, setType: .working)]
        )
        let squatLog = ExerciseLog(
            id: UUID(),
            workoutExercise: WorkoutExercise(id: UUID(), exercise: squat, recommendedSets: 3, recommendedReps: "5"),
            loggedSets: [LoggedSet(id: UUID(), weight: 275, reps: 5, restTime: 150, timestamp: end, setType: .working)]
        )
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: "Full", exercises: [benchLog.workoutExercise, squatLog.workoutExercise]),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: [benchLog, squatLog],
            sessionPlanOrigin: .workout(libraryId)
        )
        let recap = LibraryWorkoutLastSessionCopy.recap(
            forExerciseId: squatId,
            sessions: [session],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.exerciseName == "Back Squat")
        #expect(recap?.loadLine.contains("275") == true)
    }

    @Test func libraryWorkoutToStartUsesPlanOriginThenLibraryFallback() {
        let exerciseId = UUID()
        let libraryId = UUID()
        let exercise = Exercise(id: exerciseId, name: "Bench Press", description: "", targetedMuscles: [.chest])
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "8")
        let push = Workout(id: libraryId, name: "Push A", exercises: [we])
        let other = Workout(id: UUID(), name: "Pull A", exercises: [])
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Session copy", exercises: [we]),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: [
                ExerciseLog(
                    id: UUID(),
                    workoutExercise: we,
                    loggedSets: [LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: end, setType: .working)]
                )
            ],
            sessionPlanOrigin: .workout(libraryId)
        )
        let fromOrigin = LibraryWorkoutLastSessionCopy.libraryWorkoutToStart(
            forExerciseId: exerciseId,
            library: [other, push],
            sessions: [session]
        )
        #expect(fromOrigin?.id == libraryId)

        let fallback = LibraryWorkoutLastSessionCopy.libraryWorkoutToStart(
            forExerciseId: exerciseId,
            library: [other, push],
            sessions: []
        )
        #expect(fallback?.id == libraryId)
    }

    @Test func accessibilityLabelIncludesLastWorking() {
        let recap = LibraryWorkoutLastSessionCopy.Recap(
            lastDoneLine: "Last done yesterday",
            loadLine: "185 lb × 8 reps",
            exerciseName: "Bench Press",
            endedAt: Date()
        )
        #expect(recap.accessibilityLabel.contains("Last done yesterday"))
        #expect(recap.accessibilityLabel.contains("Bench Press"))
        #expect(recap.accessibilityLabel.contains("185"))
    }

    private func strengthSession(
        libraryId: UUID,
        end: Date,
        start: Date,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "8")
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: "Push A", exercises: [we]),
            startTime: start,
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: sets)],
            sessionPlanOrigin: .workout(libraryId)
        )
    }

    private func cardioSession(
        libraryId: UUID,
        end: Date,
        start: Date,
        durationSec: Int
    ) -> WorkoutSession {
        let exercise = Exercise(
            id: UUID(),
            name: "Easy Run",
            description: "",
            targetedMuscles: [],
            modality: .cardio
        )
        let we = WorkoutExercise(
            id: UUID(),
            exercise: exercise,
            recommendedSets: 1,
            recommendedReps: "",
            cardioPrescription: CardioPrescription(targetDurationSec: durationSec, targetZone: .zone2)
        )
        let set = LoggedSet(
            id: UUID(),
            weight: 0,
            reps: 0,
            restTime: 0,
            timestamp: end,
            setType: .working,
            cardioMetrics: CardioMetrics(durationSec: durationSec)
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: "Zone 2", exercises: [we], workoutKind: .cardio),
            startTime: start,
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [set])],
            sessionPlanOrigin: .workout(libraryId)
        )
    }
}
