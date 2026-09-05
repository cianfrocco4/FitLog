//
//  EntryLastSessionWorkingCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct EntryLastSessionWorkingCopyTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    @Test func skipsWarmupsAndUsesLastExerciseWorkingSet() {
        let libraryId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = multiExerciseSession(
            libraryId: libraryId,
            end: end,
            start: end.addingTimeInterval(-3600),
            benchSets: [
                LoggedSet(id: UUID(), weight: 95, reps: 8, restTime: 60, timestamp: end, setType: .warmup),
                LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: end, setType: .working)
            ],
            squatSets: [
                LoggedSet(id: UUID(), weight: 135, reps: 8, restTime: 60, timestamp: end, setType: .warmup),
                LoggedSet(id: UUID(), weight: 225, reps: 5, restTime: 150, timestamp: end, setType: .working)
            ]
        )
        let recap = EntryLastSessionWorkingCopy.recap(
            from: session,
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.lastDoneLine == "Last done today")
        #expect(recap?.loadLine.contains("225") == true)
        #expect(recap?.loadLine.contains("135") == false)
        #expect(recap?.loadLine.contains("95") == false)
        #expect(recap?.exerciseName == "Back Squat")
        #expect(recap?.accessibilityLabel.contains("last working") == true)
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
        let recap = EntryLastSessionWorkingCopy.recap(
            forLibraryWorkoutId: libraryId,
            sessions: [session],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.lastDoneLine == "Last done yesterday")
        #expect(recap?.workoutName == "Zone 2")
        #expect(recap?.loadLine.contains("45") == true)
    }

    @Test func libraryRecapPrefersMatchingWorkoutOverNewerUnrelatedSession() {
        let libraryId = UUID()
        let otherId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let matching = strengthSession(
            libraryId: libraryId,
            name: "Push A",
            end: end.addingTimeInterval(-8_000),
            start: end.addingTimeInterval(-10_000),
            sets: [LoggedSet(id: UUID(), weight: 185, reps: 8, restTime: 90, timestamp: end, setType: .working)]
        )
        let other = strengthSession(
            libraryId: otherId,
            name: "Legs A",
            end: end,
            start: end.addingTimeInterval(-1_800),
            sets: [LoggedSet(id: UUID(), weight: 315, reps: 3, restTime: 180, timestamp: end, setType: .working)]
        )
        let recap = EntryLastSessionWorkingCopy.recap(
            forLibraryWorkoutId: libraryId,
            sessions: [other, matching],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.workoutName == "Push A")
        #expect(recap?.loadLine.contains("185") == true)
    }

    @Test func latestCompletedSessionIsMostRecentEnd() {
        let olderEnd = Date(timeIntervalSince1970: 1_725_000_000)
        let newerEnd = olderEnd.addingTimeInterval(3_600)
        let older = strengthSession(
            libraryId: UUID(),
            name: "Push A",
            end: olderEnd,
            start: olderEnd.addingTimeInterval(-1_800),
            sets: [LoggedSet(id: UUID(), weight: 135, reps: 10, restTime: 90, timestamp: olderEnd, setType: .working)]
        )
        let newer = strengthSession(
            libraryId: UUID(),
            name: "Pull A",
            end: newerEnd,
            start: newerEnd.addingTimeInterval(-1_800),
            sets: [LoggedSet(id: UUID(), weight: 155, reps: 8, restTime: 90, timestamp: newerEnd, setType: .working)]
        )
        let latest = EntryLastSessionWorkingCopy.latestCompletedSession(in: [older, newer])
        #expect(latest?.workout.name == "Pull A")
    }

    @Test func sourceWorkoutPrefersLibraryPlanOrigin() {
        let libraryId = UUID()
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "8")
        let library = Workout(id: libraryId, name: "Push A", exercises: [we])
        let sessionCopy = Workout(id: UUID(), name: "Session copy", exercises: [we])
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = WorkoutSession(
            id: UUID(),
            workout: sessionCopy,
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
        let source = EntryLastSessionWorkingCopy.sourceWorkout(session: session, library: [library])
        #expect(source?.id == libraryId)
    }

    @Test func sourceWorkoutFallsBackToSessionSnapshotWhenLibraryMissing() {
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = strengthSession(
            libraryId: UUID(),
            name: "Ad hoc",
            end: end,
            start: end.addingTimeInterval(-1_800),
            sets: [LoggedSet(id: UUID(), weight: 95, reps: 12, restTime: 60, timestamp: end, setType: .working)]
        )
        let source = EntryLastSessionWorkingCopy.sourceWorkout(session: session, library: [])
        #expect(source?.name == "Ad hoc")
        #expect(source?.exercises.isEmpty == false)
    }

    @Test func a11yIdentifiersStayUniqueToEntrySurfaces() {
        #expect(FitLogA11yID.coachTabLastSession == "fitlog.coachTab.lastSession")
        #expect(FitLogA11yID.coachTabStartThisWorkout == "fitlog.coachTab.startThisWorkout")
        #expect(FitLogA11yID.programBuilderLastSession == "fitlog.programBuilder.lastSession")
        #expect(FitLogA11yID.programBuilderStartThisWorkout == "fitlog.programBuilder.startThisWorkout")
        #expect(FitLogA11yID.planEmptyLastSession == "fitlog.planEmpty.lastSession")
        #expect(FitLogA11yID.planEmptyStartThisWorkout == "fitlog.planEmpty.startThisWorkout")
    }

    private func strengthSession(
        libraryId: UUID,
        name: String,
        end: Date,
        start: Date,
        sets: [LoggedSet]
    ) -> WorkoutSession {
        let exercise = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 3, recommendedReps: "8")
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: name, exercises: [we]),
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
            name: "Zone 2 Run",
            description: "",
            targetedMuscles: [],
            modality: .cardio
        )
        let we = WorkoutExercise(id: UUID(), exercise: exercise, recommendedSets: 1, recommendedReps: "—")
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
            workout: Workout(id: libraryId, name: "Zone 2", exercises: [we], workoutKind: .cardio),
            startTime: start,
            endTime: end,
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: we, loggedSets: [set])],
            sessionPlanOrigin: .workout(libraryId)
        )
    }

    private func multiExerciseSession(
        libraryId: UUID,
        end: Date,
        start: Date,
        benchSets: [LoggedSet],
        squatSets: [LoggedSet]
    ) -> WorkoutSession {
        let bench = Exercise(id: UUID(), name: "Bench Press", description: "", targetedMuscles: [.chest])
        let squat = Exercise(id: UUID(), name: "Back Squat", description: "", targetedMuscles: [.quads])
        let benchWE = WorkoutExercise(id: UUID(), exercise: bench, recommendedSets: 3, recommendedReps: "8")
        let squatWE = WorkoutExercise(id: UUID(), exercise: squat, recommendedSets: 3, recommendedReps: "5")
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: "Full", exercises: [benchWE, squatWE]),
            startTime: start,
            endTime: end,
            exerciseLogs: [
                ExerciseLog(id: UUID(), workoutExercise: benchWE, loggedSets: benchSets),
                ExerciseLog(id: UUID(), workoutExercise: squatWE, loggedSets: squatSets)
            ],
            sessionPlanOrigin: .workout(libraryId)
        )
    }
}
