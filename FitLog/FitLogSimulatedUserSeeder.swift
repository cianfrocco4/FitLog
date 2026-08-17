//
//  FitLogSimulatedUserSeeder.swift
//  FitLog
//
//  Deterministic SwiftData seed for simulated-user UI tests. Call only after
//  `eraseAllAppData` during `-fitlog-ui-testing` launches.
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

    // MARK: - Library

    @MainActor
    private static func seedStrengthLibrary(
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
    private static func seedCardioLibrary(into dataVM: DataManager) {
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
            appendCompletedSession(
                from: workout,
                endedAt: endedAt,
                into: dataVM,
                cardio: cardio
            )
        }
    }

    @MainActor
    private static func appendCompletedSession(
        from workout: Workout,
        endedAt: Date,
        into dataVM: DataManager,
        cardio: Bool
    ) {
        guard let live = dataVM.workout(id: workout.id), let row = live.exercises.first else { return }
        let sets: [LoggedSet]
        if cardio {
            sets = [
                LoggedSet(
                    id: UUID(),
                    weight: 0,
                    reps: 0,
                    restTime: 0,
                    timestamp: endedAt,
                    cardioMetrics: CardioMetrics(durationSec: 45 * 60, distanceM: 6500, source: .manual)
                )
            ]
        } else {
            sets = (0..<3).map { i in
                LoggedSet(
                    id: UUID(),
                    weight: 135,
                    reps: 8,
                    restTime: 90,
                    timestamp: endedAt.addingTimeInterval(Double(i) * 120)
                )
            }
        }
        let log = ExerciseLog(id: UUID(), workoutExercise: row, loggedSets: sets)
        let start = endedAt.addingTimeInterval(-3600)
        let session = WorkoutSession(
            id: UUID(),
            workout: live,
            startTime: start,
            endTime: endedAt,
            exerciseLogs: [log],
            completedExerciseIds: live.exercises.compactMap(\.exerciseId),
            sessionPlanOrigin: .workout(live.id)
        )
        dataVM.appendCompletedSession(session)
    }

    // MARK: - Plan

    @MainActor
    private static func assignTodayPlan(
        into dataVM: DataManager,
        now: Date,
        calendar: Calendar
    ) {
        guard let workout = dataVM.userWorkouts.first else { return }
        let dayKey = TrainingProgramState.dayKey(for: now, calendar: calendar)
        let weekday = calendar.component(.weekday, from: now)
        dataVM.trainingProgram = TrainingProgramState(
            cycleEntries: [.workout(workout.id)],
            sessionsPerWeek: 3,
            preferredWeekdays: [weekday],
            anchorDayKey: dayKey,
            cyclePhaseOffset: 0,
            skippedCycleTrainingDayKeys: [],
            dayOverrides: [
                dayKey: ScheduleDayOverride(intent: .workout, planRef: .workout(workout.id))
            ],
            weekOverrides: [:],
            frozenCalendarDays: [:]
        )
        dataVM.saveTrainingProgram()
    }
}
