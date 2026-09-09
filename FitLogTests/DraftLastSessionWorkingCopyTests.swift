//
//  DraftLastSessionWorkingCopyTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct DraftLastSessionWorkingCopyTests {
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
        let recap = DraftLastSessionWorkingCopy.recap(
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
            name: "Zone 2 · 45 min",
            exerciseName: "Zone 2 Run",
            end: yesterday,
            start: yesterday.addingTimeInterval(-45 * 60),
            durationSec: 45 * 60
        )
        let recap = DraftLastSessionWorkingCopy.recap(
            forLibraryWorkoutId: libraryId,
            sessions: [session],
            weightUnit: .pounds,
            now: end,
            calendar: calendar
        )
        #expect(recap?.lastDoneLine == "Last done yesterday")
        #expect(recap?.workoutName == "Zone 2 · 45 min")
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
        let recap = DraftLastSessionWorkingCopy.recap(
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
        let latest = DraftLastSessionWorkingCopy.latestCompletedSession(in: [older, newer])
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
        let source = DraftLastSessionWorkingCopy.sourceWorkout(session: session, library: [library])
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
        let source = DraftLastSessionWorkingCopy.sourceWorkout(session: session, library: [])
        #expect(source?.name == "Ad hoc")
        #expect(source?.exercises.isEmpty == false)
    }

    @Test func lastCardioFillSkipsIntervalRestAndPrefersSameWorkout() {
        let exerciseId = UUID()
        let preferredWorkoutId = UUID()
        let otherWorkoutId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let olderSame = cardioSession(
            libraryId: preferredWorkoutId,
            name: "Zone 2 · 45 min",
            exerciseId: exerciseId,
            exerciseName: "Zone 2 Run",
            end: end.addingTimeInterval(-86_400),
            start: end.addingTimeInterval(-86_400 - 40 * 60),
            durationSec: 40 * 60,
            distanceM: 6_000
        )
        let newerOther = cardioSession(
            libraryId: otherWorkoutId,
            name: "Tempo",
            exerciseId: exerciseId,
            exerciseName: "Zone 2 Run",
            end: end,
            start: end.addingTimeInterval(-20 * 60),
            durationSec: 20 * 60
        )
        let restOnly = cardioSession(
            libraryId: UUID(),
            name: "Intervals",
            exerciseId: exerciseId,
            exerciseName: "Zone 2 Run",
            end: end.addingTimeInterval(60),
            start: end,
            durationSec: 90,
            setType: .intervalRest
        )
        let fill = DraftLastSessionWorkingCopy.lastCardioFill(
            matchingExerciseIds: [exerciseId],
            in: [newerOther, olderSame, restOnly],
            preferredWorkoutId: preferredWorkoutId,
            now: end,
            calendar: calendar
        )
        #expect(fill?.durationSec == 40 * 60)
        #expect(fill?.distanceM == 6_000)
        #expect(fill?.summaryLine.isEmpty == false)
        #expect(fill?.exerciseName == "Zone 2 Run")
    }

    @Test func lastCardioFillFallsBackToAnyWorkoutWhenPreferredMissing() {
        let exerciseId = UUID()
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = cardioSession(
            libraryId: UUID(),
            name: "Zone 2 · 45 min",
            exerciseId: exerciseId,
            exerciseName: "Easy jog",
            end: end,
            start: end.addingTimeInterval(-45 * 60),
            durationSec: 45 * 60,
            avgHeartRate: 142,
            calories: 380
        )
        let fill = DraftLastSessionWorkingCopy.lastCardioFill(
            matchingExerciseIds: [exerciseId],
            in: [session],
            preferredWorkoutId: UUID(),
            now: end,
            calendar: calendar
        )
        #expect(fill?.durationSec == 45 * 60)
        #expect(fill?.avgHeartRate == 142)
        #expect(fill?.calories == 380)
        #expect(fill?.accessibilityLabel.contains("Easy jog") == true)
    }

    @Test func lastCardioDurationLineMatchesTemplateName() {
        let end = Date(timeIntervalSince1970: 1_725_000_000)
        let session = cardioSession(
            libraryId: UUID(),
            name: "Zone 2 · 45 min",
            exerciseName: "Zone 2 Run",
            end: end,
            start: end.addingTimeInterval(-45 * 60),
            durationSec: 45 * 60
        )
        let line = DraftLastSessionWorkingCopy.lastCardioDurationLine(
            matchingTemplateName: "Zone 2 · 45 min",
            in: [session],
            now: end,
            calendar: calendar
        )
        #expect(line?.contains("Last done today") == true)
        #expect(line?.contains("45") == true)
        let miss = DraftLastSessionWorkingCopy.lastCardioDurationLine(
            matchingTemplateName: "5K Progression",
            in: [session],
            now: end,
            calendar: calendar
        )
        #expect(miss == nil)
    }

    @Test func a11yIdentifiersStayUniqueToDraftSurfaces() {
        #expect(FitLogA11yID.newWorkoutSheetLastSession == "fitlog.newWorkoutSheet.lastSession")
        #expect(FitLogA11yID.newWorkoutSheetStartThisWorkout == "fitlog.newWorkoutSheet.startThisWorkout")
        #expect(FitLogA11yID.cardioLogLastDuration == "fitlog.cardioLog.lastDuration")
        #expect(FitLogA11yID.cardioLogUseLastTime == "fitlog.cardioLog.useLastTime")
        #expect(FitLogA11yID.cardioTemplatePickerLastDuration == "fitlog.cardioTemplatePicker.lastDuration")
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
        name: String,
        exerciseId: UUID = UUID(),
        exerciseName: String,
        end: Date,
        start: Date,
        durationSec: Int,
        distanceM: Double? = nil,
        avgHeartRate: Int? = nil,
        calories: Double? = nil,
        setType: ExerciseSetType = .steadyState
    ) -> WorkoutSession {
        let exercise = Exercise(
            id: exerciseId,
            name: exerciseName,
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
            setType: setType,
            cardioMetrics: CardioMetrics(
                durationSec: durationSec,
                distanceM: distanceM,
                avgHeartRate: avgHeartRate,
                calories: calories,
                source: .manual
            )
        )
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: libraryId, name: name, exercises: [we], workoutKind: .cardio),
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
