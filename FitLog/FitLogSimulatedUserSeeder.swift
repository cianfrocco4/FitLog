//
//  FitLogSimulatedUserSeeder.swift
//  FitLog
//
//  Snapshot seed (after erase) for one-shot XCUITests, plus helpers for daily living ticks.
//

import Foundation

enum FitLogSimulatedUserSeeder {

    @MainActor
    static func seed(
        _ persona: FitLogSimulatedUserPersona,
        into dataVM: DataManager,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        switch persona {
        case .newFree:
            break
        case .returningFree:
            seedStrengthLibrary(into: dataVM, templates: Array(WorkoutQuickStartTemplate.all.prefix(3)))
            seedCompletedSessions(
                into: dataVM,
                now: now,
                calendar: calendar,
                recentOffsets: [1, 3, 6, 10],
                olderOffsets: [40, 48]
            )
        case .premiumLifter:
            seedStrengthLibrary(into: dataVM, templates: Array(WorkoutQuickStartTemplate.all.prefix(3)))
            seedCompletedSessions(
                into: dataVM,
                now: now,
                calendar: calendar,
                recentOffsets: [0, 2, 4, 7, 9, 11, 14, 18],
                olderOffsets: [32, 45, 60]
            )
        case .cardioHobbyist:
            seedCardioLibrary(into: dataVM)
            seedCompletedSessions(
                into: dataVM,
                now: now,
                calendar: calendar,
                recentOffsets: [2, 5],
                olderOffsets: [],
                cardio: true
            )
        case .planFollower:
            seedStrengthLibrary(into: dataVM, templates: Array(WorkoutQuickStartTemplate.all.prefix(1)))
            assignTodayPlan(into: dataVM, now: now, calendar: calendar)
        }
    }

    /// Creates library workouts when empty. Does not invent past sessions.
    @MainActor
    static func bootstrapLibraryIfNeeded(
        _ persona: FitLogSimulatedUserPersona,
        into dataVM: DataManager,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard dataVM.userWorkouts.isEmpty else {
            if persona == .planFollower {
                refreshPlanAssignment(into: dataVM, now: now, calendar: calendar)
            }
            return
        }
        switch persona {
        case .newFree:
            seedStrengthLibrary(into: dataVM, templates: Array(WorkoutQuickStartTemplate.all.prefix(1)))
        case .returningFree, .premiumLifter:
            seedStrengthLibrary(into: dataVM, templates: Array(WorkoutQuickStartTemplate.all.prefix(3)))
        case .cardioHobbyist:
            seedCardioLibrary(into: dataVM)
        case .planFollower:
            seedStrengthLibrary(into: dataVM, templates: Array(WorkoutQuickStartTemplate.all.prefix(1)))
            assignRecurringPlan(into: dataVM, now: now, calendar: calendar, weekdays: Array(persona.trainingWeekdays).sorted())
        }
    }

    // MARK: - Library

    @MainActor
    static func seedStrengthLibrary(
        into dataVM: DataManager,
        templates: [WorkoutQuickStartTemplate]
    ) {
        for tpl in templates {
            let id = dataVM.createWorkout(name: dataVM.uniqueWorkoutName(tpl.defaultWorkoutName))
            let resolved = WorkoutStarterResolution.resolvedTemplate(tpl, library: dataVM.globalExercises)
            for item in resolved {
                guard let fresh = dataVM.workout(id: id) else { break }
                _ = dataVM.addExercise(
                    to: fresh,
                    exercise: item.exercise,
                    recommendedSets: item.sets,
                    recommendedReps: item.reps,
                    configurationFields: [],
                    recommendedConfigBySet: Array(repeating: [:], count: item.sets)
                )
            }
        }
    }

    @MainActor
    static func seedCardioLibrary(into dataVM: DataManager) {
        let template = CardioTemplateLibrary.zone2FortyFive
        let id = dataVM.createCardioWorkout(
            name: dataVM.uniqueWorkoutName(template.name),
            kind: .cardio
        )
        let resolved = CardioTemplateLibrary.resolveRows(template.rows, library: dataVM.globalExercises)
        for item in resolved {
            guard let fresh = dataVM.workout(id: id) else { break }
            _ = dataVM.addCardioExercise(to: fresh, exercise: item.exercise, prescription: item.prescription)
        }
    }

    // MARK: - History

    @MainActor
    private static func seedCompletedSessions(
        into dataVM: DataManager,
        now: Date,
        calendar: Calendar,
        recentOffsets: [Int],
        olderOffsets: [Int],
        cardio: Bool = false
    ) {
        let workouts = dataVM.userWorkouts
        guard !workouts.isEmpty else { return }
        let offsets = recentOffsets + olderOffsets
        for (index, dayOffset) in offsets.enumerated() {
            let workout = workouts[index % workouts.count]
            guard let endedAt = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            _ = logCompletedWorkout(
                from: workout,
                endedAt: endedAt,
                into: dataVM,
                cardio: cardio
            )
        }
    }

    /// Appends one finished session. Returns false when the workout has no loggable rows.
    @discardableResult
    @MainActor
    static func logCompletedWorkout(
        from workout: Workout,
        endedAt: Date,
        into dataVM: DataManager,
        cardio: Bool,
        workingWeight: Double = 135
    ) -> Bool {
        guard let live = dataVM.workout(id: workout.id) else { return false }
        let rows = Array(live.exercises.prefix(cardio ? 1 : 4))
        guard !rows.isEmpty else { return false }

        let extraMinutes = dataVM.completedSessions.count
        let exerciseLogs: [ExerciseLog] = rows.enumerated().map { offset, row in
            let sets: [LoggedSet]
            if cardio {
                sets = [
                    LoggedSet(
                        id: UUID(),
                        weight: 0,
                        reps: 0,
                        restTime: 0,
                        timestamp: endedAt,
                        setType: .steadyState,
                        cardioMetrics: CardioMetrics(
                            durationSec: (45 + extraMinutes) * 60,
                            distanceM: 6500 + Double(extraMinutes) * 100,
                            source: .manual
                        )
                    )
                ]
            } else {
                sets = (0..<3).map { i in
                    LoggedSet(
                        id: UUID(),
                        weight: workingWeight,
                        reps: 8,
                        restTime: 90,
                        timestamp: endedAt.addingTimeInterval(Double(offset * 400 + i * 120)),
                        setType: .working
                    )
                }
            }
            return ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)
        }
        let start = endedAt.addingTimeInterval(-3600)
        let session = WorkoutSession(
            id: UUID(),
            workout: live,
            startTime: start,
            endTime: endedAt,
            exerciseLogs: exerciseLogs,
            completedExerciseIds: rows.compactMap(\.exerciseId),
            sessionPlanOrigin: .workout(live.id)
        )
        dataVM.appendCompletedSession(session)
        return true
    }

    // MARK: - Plan

    @MainActor
    static func assignTodayPlan(
        into dataVM: DataManager,
        now: Date,
        calendar: Calendar
    ) {
        let weekday = calendar.component(.weekday, from: now)
        assignRecurringPlan(into: dataVM, now: now, calendar: calendar, weekdays: [weekday])
    }

    @MainActor
    static func assignRecurringPlan(
        into dataVM: DataManager,
        now: Date,
        calendar: Calendar,
        weekdays: [Int]
    ) {
        guard let workout = dataVM.userWorkouts.first else { return }
        let dayKey = TrainingProgramState.dayKey(for: now, calendar: calendar)
        var overrides = dataVM.trainingProgram.dayOverrides
        if weekdays.contains(calendar.component(.weekday, from: now)) {
            overrides[dayKey] = ScheduleDayOverride(intent: .workout, planRef: .workout(workout.id))
        }
        dataVM.trainingProgram = TrainingProgramState(
            cycleEntries: dataVM.userWorkouts.map { .workout($0.id) },
            sessionsPerWeek: max(1, weekdays.count),
            preferredWeekdays: weekdays.sorted(),
            anchorDayKey: dataVM.trainingProgram.anchorDayKey.isEmpty
                ? dayKey
                : dataVM.trainingProgram.anchorDayKey,
            cyclePhaseOffset: dataVM.trainingProgram.cyclePhaseOffset,
            skippedCycleTrainingDayKeys: dataVM.trainingProgram.skippedCycleTrainingDayKeys,
            dayOverrides: overrides,
            weekOverrides: dataVM.trainingProgram.weekOverrides,
            frozenCalendarDays: dataVM.trainingProgram.frozenCalendarDays
        )
        dataVM.saveTrainingProgram()
    }

    @MainActor
    static func refreshPlanAssignment(
        into dataVM: DataManager,
        now: Date,
        calendar: Calendar
    ) {
        let weekdays = dataVM.trainingProgram.preferredWeekdays.isEmpty
            ? Array(FitLogSimulatedUserPersona.planFollower.trainingWeekdays).sorted()
            : dataVM.trainingProgram.preferredWeekdays
        assignRecurringPlan(into: dataVM, now: now, calendar: calendar, weekdays: weekdays)
    }
}
