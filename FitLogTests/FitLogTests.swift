//
//  FitLogTests.swift
//  FitLogTests
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

struct FitLogTests {

    @Test func trainingScheduleEngine_skippedTrainingDayDoesNotAdvanceCycle() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let engine = TrainingScheduleEngine(calendar: cal)
        let idPush = UUID(), idPull = UUID(), idLegs = UUID()
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let dayKey = TrainingProgramState.dayKey(for: anchor, calendar: cal)
        let mon = anchor
        let wed = cal.date(byAdding: .day, value: 2, to: mon)!
        let fri = cal.date(byAdding: .day, value: 4, to: mon)!
        var program = TrainingProgramState(
            cycleEntries: [.workout(idPush), .workout(idPull), .workout(idLegs)],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 4, 6],
            anchorDayKey: dayKey,
            cyclePhaseOffset: 0,
            skippedCycleTrainingDayKeys: [dayKey],
            dayOverrides: [:],
            weekOverrides: [:]
        )
        // Monday was a planned workout day but skipped — rotation should not advance past it.
        #expect(engine.defaultCycleEntry(for: wed, program: program) == .workout(idPush))
        #expect(engine.defaultCycleEntry(for: fri, program: program) == .workout(idPull))
        program.skippedCycleTrainingDayKeys = []
        #expect(engine.defaultCycleEntry(for: wed, program: program) == .workout(idPull))
    }

    @Test func trainingScheduleEngine_assignsCycleOnPreferredTrainingDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let engine = TrainingScheduleEngine(calendar: cal)
        let idPush = UUID(), idPull = UUID(), idLegs = UUID()
        // 2026-03-16 is a Monday (US calendar: weekday 2).
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let dayKey = TrainingProgramState.dayKey(for: anchor, calendar: cal)
        let program = TrainingProgramState(
            cycleEntries: [
                .workout(idPush),
                .workout(idPull),
                .workout(idLegs)
            ],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 4, 6],
            anchorDayKey: dayKey,
            dayOverrides: [:],
            weekOverrides: [:]
        )
        let mon = anchor
        let wed = cal.date(byAdding: .day, value: 2, to: mon)!
        let fri = cal.date(byAdding: .day, value: 4, to: mon)!
        #expect(engine.resolve(date: mon, program: program) == .workout(.workout(idPush)))
        #expect(engine.resolve(date: wed, program: program) == .workout(.workout(idPull)))
        #expect(engine.resolve(date: fri, program: program) == .workout(.workout(idLegs)))
    }

    @Test func trainingScheduleEngine_dayOverrideBeatsDefault() {
        let cal = Calendar(identifier: .gregorian)
        let engine = TrainingScheduleEngine(calendar: cal)
        let idA = UUID(), idB = UUID()
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let mon = anchor
        let dayKey = TrainingProgramState.dayKey(for: mon, calendar: cal)
        let program = TrainingProgramState(
            cycleEntries: [.workout(idA)],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 3, 4],
            anchorDayKey: TrainingProgramState.dayKey(for: anchor, calendar: cal),
            dayOverrides: [dayKey: ScheduleDayOverride(intent: .workout, workoutId: idB)],
            weekOverrides: [:]
        )
        #expect(engine.resolve(date: mon, program: program) == .workout(.workout(idB)))
    }

    @Test func trainingScheduleEngine_dayOverrideSupportsUnifiedWorkoutRef() {
        let cal = Calendar(identifier: .gregorian)
        let engine = TrainingScheduleEngine(calendar: cal)
        let idTemplate = UUID()
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let mon = anchor
        let dayKey = TrainingProgramState.dayKey(for: mon, calendar: cal)
        let program = TrainingProgramState(
            cycleEntries: [.workout(UUID())],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 3, 4],
            anchorDayKey: TrainingProgramState.dayKey(for: anchor, calendar: cal),
            dayOverrides: [dayKey: ScheduleDayOverride(intent: .workout, planRef: .workout(idTemplate))],
            weekOverrides: [:]
        )
        #expect(engine.resolve(date: mon, program: program) == .workout(.workout(idTemplate)))
    }

    @Test func scheduleDayOverride_encodesRoundTrip() throws {
        let original = ScheduleDayOverride(intent: .workout, planRef: .workout(UUID()))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScheduleDayOverride.self, from: data)
        #expect(decoded == original)
    }

    @Test func trainingProgramState_decodesPartialJSONWithoutThrowing() throws {
        let json = Data(#"{"cycleWorkoutIds":[],"sessionsPerWeek":4}"#.utf8)
        let decoded = try JSONDecoder().decode(TrainingProgramState.self, from: json)
        #expect(decoded.sessionsPerWeek == 4)
        #expect(decoded.cycleEntries.isEmpty)
        #expect(decoded.preferredWeekdays.isEmpty)
        #expect(decoded.frozenCalendarDays.isEmpty)
    }

    @Test func frozenPlanDay_encodesRoundTrip() throws {
        let id = UUID()
        let original = FrozenPlanDay(resolved: .workout(.workout(id)))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FrozenPlanDay.self, from: data)
        #expect(decoded == original)
        #expect(decoded.asResolved() == .workout(.workout(id)))
    }

    @Test func trainingProgramState_remappingWorkoutPlanRefs() {
        let oldId = UUID(), newId = UUID()
        var program = TrainingProgramState(
            cycleEntries: [.workout(oldId)],
            sessionsPerWeek: 3,
            preferredWeekdays: [],
            anchorDayKey: "2026-01-01",
            dayOverrides: [:],
            weekOverrides: [:],
            frozenCalendarDays: [:]
        )
        program = program.remappingWorkoutPlanRefs([oldId: newId])
        #expect(program.cycleEntries == [.workout(newId)])
    }

    @Test func workoutPlanRef_decodesLegacyConcreteWorkoutJSON() throws {
        let id = UUID()
        let json = Data(#"{"concreteWorkout":"\#(id.uuidString)"}"#.utf8)
        let decoded = try JSONDecoder().decode(WorkoutPlanRef.self, from: json)
        #expect(decoded == .workout(id))
    }

    @Test func slotResolution_decodesLegacyUnresolved() throws {
        let sid = UUID()
        let json = Data(#"{"unresolved":{"slotLabel":"Push","templateSlotId":"\#(sid.uuidString)"}}"#.utf8)
        let decoded = try JSONDecoder().decode(SlotResolution.self, from: json)
        if case .flexible(let b) = decoded {
            #expect(b.id == sid)
            #expect(b.label == "Push")
        } else {
            #expect(Bool(false), "Expected flexible blueprint")
        }
    }

    @Test func exerciseSnapshot_decodesLegacyIdAndNameKeys() throws {
        let eid = UUID()
        let json = Data(#"{"id":"\#(eid.uuidString)","name":"Squat"}"#.utf8)
        let decoded = try JSONDecoder().decode(ExerciseSnapshot.self, from: json)
        #expect(decoded.exerciseId == eid)
        #expect(decoded.nameAtTimeOfLog == "Squat")
    }

    @Test func slotResolution_decodesConcreteLegacyFullExercise() throws {
        let eid = UUID()
        let json = Data(
            #"""
            {"concrete":{"id":"\#(eid.uuidString)","name":"Bench Press","description":"","targetedMuscles":[]}}
            """#.utf8
        )
        let decoded = try JSONDecoder().decode(SlotResolution.self, from: json)
        if case .concrete(let s) = decoded {
            #expect(s.exerciseId == eid)
            #expect(s.nameAtTimeOfLog == "Bench Press")
        } else {
            #expect(Bool(false), "Expected concrete snapshot from legacy Exercise payload")
        }
    }

    @Test func workoutExercise_keepsConcreteWhenConcretePayloadWasFullExercise() throws {
        let rowId = UUID()
        let eid = UUID()
        let json = Data(
            #"""
            {"id":"\#(rowId.uuidString)","resolution":{"concrete":{"id":"\#(eid.uuidString)","name":"Row","description":"","targetedMuscles":[]}},"defaultRestTime":90,"recommendedSets":3,"recommendedReps":"8-12","configurationFields":[],"recommendedConfigBySet":[]}
            """#.utf8
        )
        let decoded = try JSONDecoder().decode(WorkoutExercise.self, from: json)
        #expect(decoded.id == rowId)
        if case .concrete(let s) = decoded.resolution {
            #expect(s.exerciseId == eid)
            #expect(s.nameAtTimeOfLog == "Row")
        } else {
            #expect(Bool(false), "Expected concrete row, not empty flexible fallback")
        }
    }

    @Test func workoutExercise_exerciseId_includesFlexibleDefault() {
        let eid = UUID()
        let bid = UUID()
        let b = SlotBlueprint(id: bid, label: "Horizontal push", targetedMuscles: [.chest], defaultExerciseId: eid)
        let we = WorkoutExercise(id: UUID(), resolution: .flexible(b))
        #expect(we.exerciseId == eid)
        #expect(!we.isOpenSlot)
        #expect(we.isSlotPlaceholder == false)
    }

    @Test func unifiedSlotsMigration_convertsConcreteLibraryRow() {
        let exId = UUID()
        let rowId = UUID()
        let wid = UUID()
        let libraryExercise = Exercise(
            id: exId,
            name: "Back Squat",
            description: "",
            targetedMuscles: [.quads, .glutes],
            isCustom: false,
            configurationOptions: [],
            exerciseRole: .compound,
            movementPattern: .squat
        )
        let snap = ExerciseSnapshot(exerciseId: exId, nameAtTimeOfLog: "Back Squat")
        let we = WorkoutExercise(
            id: rowId,
            resolution: .concrete(snap),
            defaultRestTime: 120,
            recommendedSets: 4,
            recommendedReps: "5",
            configurationFields: [],
            recommendedConfigBySet: []
        )
        var workouts = [Workout(id: wid, name: "Legs", exercises: [we], templateSlotIdByWorkoutExerciseId: [:])]
        let changed = WorkoutUnifiedSlotsMigration.migrateWorkoutsInPlace(&workouts, globalExercises: [libraryExercise])
        #expect(changed == true)
        guard case .flexible(let b) = workouts[0].exercises[0].resolution else {
            #expect(Bool(false), "Expected flexible blueprint")
            return
        }
        #expect(b.defaultExerciseId == exId)
        #expect(b.label == "Back Squat")
        #expect(workouts[0].templateSlotIdByWorkoutExerciseId[rowId] == b.id)
        #expect(workouts[0].exercises[0].recommendedSets == 4)
        #expect(workouts[0].exercises[0].recommendedReps == "5")
    }

    @Test func unifiedSlotsMigration_migratesSessionSnapshotAndSyncsLogs() {
        let exId = UUID()
        let rowId = UUID()
        let sessionId = UUID()
        let libraryExercise = Exercise(
            id: exId,
            name: "Bench Press",
            description: "",
            targetedMuscles: [.chest],
            isCustom: false,
            configurationOptions: [],
            exerciseRole: .compound,
            movementPattern: .horizontalPush
        )
        let snap = ExerciseSnapshot(exerciseId: exId, nameAtTimeOfLog: "Bench Press")
        let we = WorkoutExercise(id: rowId, resolution: .concrete(snap), recommendedSets: 3, recommendedReps: "8")
        let workout = Workout(id: UUID(), name: "Push", exercises: [we], templateSlotIdByWorkoutExerciseId: [:])
        let log = ExerciseLog(
            id: UUID(),
            workoutExercise: we,
            loggedSets: []
        )
        var session = WorkoutSession(
            id: sessionId,
            workout: workout,
            startTime: Date(),
            endTime: Date(),
            exerciseLogs: [log],
            sessionPlanOrigin: .workout(UUID())
        )
        let changed = WorkoutUnifiedSlotsMigration.migrateSessionConcreteSnapshotInPlace(&session, globalExercises: [libraryExercise])
        #expect(changed == true)
        guard case .flexible(let b) = session.workout.exercises[0].resolution else {
            #expect(Bool(false), "Expected flexible in session workout")
            return
        }
        #expect(b.defaultExerciseId == exId)
        guard case .flexible = session.exerciseLogs[0].workoutExercise.resolution else {
            #expect(Bool(false), "Expected log row synced to flexible")
            return
        }
        #expect(session.exerciseLogs[0].workoutExercise.id == rowId)
    }

    @Test func splitProposalProgramAnalyzer_countsSetsAndInfersPPL() {
        let days: [SplitProposalProgramAnalyzer.DayInput] = [
            .init(
                name: "Push",
                focus: "",
                slots: [
                    .init(label: "Chest", targetMuscleNames: [MuscleGroup.chest.rawValue], sets: 4),
                    .init(label: "Delts", targetMuscleNames: [MuscleGroup.frontDelts.rawValue], sets: 3)
                ]
            ),
            .init(
                name: "Pull",
                focus: "",
                slots: [
                    .init(label: "Back", targetMuscleNames: [MuscleGroup.lats.rawValue], sets: 4)
                ]
            ),
            .init(
                name: "Legs",
                focus: "",
                slots: [
                    .init(label: "Quads", targetMuscleNames: [MuscleGroup.quads.rawValue], sets: 5)
                ]
            )
        ]
        let stats = SplitProposalProgramAnalyzer.stats(for: days)
        #expect(stats.totalHardSetsPerWeek == 16)
        #expect(stats.inferredSplitStyle.contains("Push"))
        let warns = SplitProposalProgramAnalyzer.warnings(stats: stats, days: days)
        #expect(warns.contains { $0.message.contains("leg") } == false)
    }

    @Test func splitProposalProgramAnalyzer_warnsWhenNoLegs() {
        let days: [SplitProposalProgramAnalyzer.DayInput] = [
            .init(
                name: "Upper",
                focus: "",
                slots: [
                    .init(label: "Chest", targetMuscleNames: [MuscleGroup.chest.rawValue], sets: 6),
                    .init(label: "Back", targetMuscleNames: [MuscleGroup.lats.rawValue], sets: 6)
                ]
            )
        ]
        let stats = SplitProposalProgramAnalyzer.stats(for: days)
        let warns = SplitProposalProgramAnalyzer.warnings(stats: stats, days: days)
        #expect(warns.contains { $0.message.localizedCaseInsensitiveContains("leg") })
    }

    // MARK: - Dynamic program rotation / makeup

    @Test func scheduleAdaptation_onPlanCompletionsPreserveRotationOrder() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1], idLegs = workoutIds[2]

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        let adapter = ScheduleAdaptationService(calendar: cal)
        let pe = PeriodizationEngine(calendar: cal)

        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal),
            Self.completedSession(on: fri, workoutId: idLegs, name: "Legs", calendar: cal)
        ]
        let nextMonday = cal.date(byAdding: .day, value: 7, to: mon)!
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            asOf: cal.date(byAdding: .day, value: 1, to: nextMonday)!
        )

        #expect(state.skippedProgramTrainingDayKeys.isEmpty)
        let nextIdx = pe.cycleTemplateIndex(on: nextMonday, state: state, templatesCount: 3)
        #expect(nextIdx == 0)
        #expect(state.materializedTemplateWorkoutIds[templates[nextIdx!].id] == idPush)
    }

    @Test func scheduleAdaptation_offDayMakeupCreditsMissedSlotAndAdvancesRotation() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1], idLegs = workoutIds[2]
        let sunday = cal.date(byAdding: .day, value: 6, to: mon)!
        let nextMonday = cal.date(byAdding: .day, value: 7, to: mon)!

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        let adapter = ScheduleAdaptationService(calendar: cal)
        let pe = PeriodizationEngine(calendar: cal)

        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal),
            Self.completedSession(on: sunday, workoutId: idLegs, name: "Legs", calendar: cal, origin: idLegs)
        ]
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            asOf: nextMonday
        )

        let friKey = TrainingProgramState.dayKey(for: fri, calendar: cal)
        #expect(!state.skippedProgramTrainingDayKeys.contains(friKey))
        let nextIdx = pe.cycleTemplateIndex(on: nextMonday, state: state, templatesCount: 3)
        #expect(nextIdx == 0)
        #expect(state.materializedTemplateWorkoutIds[templates[nextIdx!].id] == idPush)
    }

    @Test func scheduleAdaptation_unrelatedOffDayWorkoutDoesNotCreditMissedSlot() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1], idLegs = workoutIds[2]
        let unrelatedId = UUID()
        let sunday = cal.date(byAdding: .day, value: 6, to: mon)!
        let nextMonday = cal.date(byAdding: .day, value: 7, to: mon)!

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        let adapter = ScheduleAdaptationService(calendar: cal)
        let pe = PeriodizationEngine(calendar: cal)

        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal),
            Self.completedSession(on: sunday, workoutId: unrelatedId, name: "Cardio", calendar: cal, origin: unrelatedId)
        ]
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            asOf: nextMonday
        )

        let friKey = TrainingProgramState.dayKey(for: fri, calendar: cal)
        #expect(state.skippedProgramTrainingDayKeys.contains(friKey))
        let nextIdx = pe.cycleTemplateIndex(on: nextMonday, state: state, templatesCount: 3)
        #expect(nextIdx == 2)
        #expect(state.materializedTemplateWorkoutIds[templates[nextIdx!].id] == idLegs)
    }

    @Test func scheduleAdaptation_manualRestOverrideDoesNotMarkDayMissed() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1]
        let nextMonday = cal.date(byAdding: .day, value: 7, to: mon)!
        let friKey = TrainingProgramState.dayKey(for: fri, calendar: cal)

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        let adapter = ScheduleAdaptationService(calendar: cal)
        let dayOverrides = [friKey: ScheduleDayOverride(intent: .rest)]

        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal)
        ]
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            dayOverrides: dayOverrides,
            asOf: nextMonday
        )

        #expect(!state.skippedProgramTrainingDayKeys.contains(friKey))
    }

    @Test func scheduleAdaptation_duplicateWorkoutMappingDoesNotTrap() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1], idLegs = workoutIds[2]
        let nextMonday = cal.date(byAdding: .day, value: 7, to: mon)!

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        state.materializedTemplateWorkoutIds = [
            templates[0].id: idLegs,
            templates[1].id: idPull,
            templates[2].id: idLegs
        ]

        let adapter = ScheduleAdaptationService(calendar: cal)
        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal),
            Self.completedSession(on: fri, workoutId: idLegs, name: "Legs", calendar: cal, origin: idLegs)
        ]
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            asOf: nextMonday
        )
        #expect(state.skippedProgramTrainingDayKeys.isEmpty)
    }

    @Test func scheduleAdaptation_singleMakeupClearsExactlyOneMissedSlot() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1], idLegs = workoutIds[2]
        let friWeek2 = cal.date(byAdding: .day, value: 7, to: fri)!
        let sundayWeek2 = cal.date(byAdding: .day, value: 2, to: friWeek2)!
        let monWeek3 = cal.date(byAdding: .day, value: 3, to: friWeek2)!
        let friKey1 = TrainingProgramState.dayKey(for: fri, calendar: cal)
        let friKey2 = TrainingProgramState.dayKey(for: friWeek2, calendar: cal)

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        let adapter = ScheduleAdaptationService(calendar: cal)

        let monWeek2 = cal.date(byAdding: .day, value: 7, to: mon)!
        let wedWeek2 = cal.date(byAdding: .day, value: 7, to: wed)!
        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal),
            Self.completedSession(on: monWeek2, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wedWeek2, workoutId: idPull, name: "Pull", calendar: cal),
            Self.completedSession(on: sundayWeek2, workoutId: idLegs, name: "Legs", calendar: cal, origin: idLegs)
        ]
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            asOf: monWeek3
        )

        #expect(state.skippedProgramTrainingDayKeys.contains(friKey1) != state.skippedProgramTrainingDayKeys.contains(friKey2))
        #expect(state.skippedProgramTrainingDayKeys.count == 1)
    }

    @Test func scheduleAdaptation_frozenRestDayIsNotMarkedMissed() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let idPush = workoutIds[0], idPull = workoutIds[1]
        let nextMonday = cal.date(byAdding: .day, value: 7, to: mon)!
        let friKey = TrainingProgramState.dayKey(for: fri, calendar: cal)

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        let adapter = ScheduleAdaptationService(calendar: cal)
        let frozen = [friKey: FrozenPlanDay(kind: .rest)]

        let sessions = [
            Self.completedSession(on: mon, workoutId: idPush, name: "Push", calendar: cal),
            Self.completedSession(on: wed, workoutId: idPull, name: "Pull", calendar: cal)
        ]
        adapter.mergeSkippedRotationKeysThroughYesterday(
            state: &state,
            completedSessions: sessions,
            frozenCalendarDays: frozen,
            asOf: nextMonday
        )

        #expect(!state.skippedProgramTrainingDayKeys.contains(friKey))
    }

    @Test @MainActor func outstandingMissedMakeups_honorsLimitAndOrdering() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        let (anchor, mon, wed, fri, templates, workoutIds) = Self.monWedFriFixture(calendar: cal)
        let friWeek2 = cal.date(byAdding: .day, value: 7, to: fri)!
        let friKey1 = TrainingProgramState.dayKey(for: fri, calendar: cal)
        let friKey2 = TrainingProgramState.dayKey(for: friWeek2, calendar: cal)

        var state = Self.dynamicState(
            anchor: anchor,
            templates: templates,
            workoutIds: workoutIds,
            calendar: cal
        )
        state.skippedProgramTrainingDayKeys = [friKey2, friKey1]

        let container = try Self.makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        dm.dynamicProgramState = state
        dm.userWorkouts = [
            Workout(id: workoutIds[0], name: "Push", exercises: []),
            Workout(id: workoutIds[1], name: "Pull", exercises: []),
            Workout(id: workoutIds[2], name: "Legs", exercises: [])
        ]

        let all = dm.outstandingMissedMakeups(calendar: cal)
        #expect(all.count == 2)
        #expect(all[0].dayKey == friKey1)
        #expect(all[1].dayKey == friKey2)
        #expect(all[0].workout.name == "Legs")

        let limited = dm.outstandingMissedMakeups(calendar: cal, limit: 1)
        #expect(limited.count == 1)
        #expect(limited[0].dayKey == friKey1)
    }
}

// MARK: - Dynamic program test fixtures

private extension FitLogTests {
    static func monWedFriFixture(calendar: Calendar) -> (
        anchor: Date,
        mon: Date,
        wed: Date,
        fri: Date,
        templates: [BlockWeeklyTemplate],
        workoutIds: [UUID]
    ) {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let mon = anchor
        let wed = calendar.date(byAdding: .day, value: 2, to: mon)!
        let fri = calendar.date(byAdding: .day, value: 4, to: mon)!
        let slot = SplitBuilderEditableSlot(
            label: "Main",
            targetMuscleNames: [MuscleGroup.chest.rawValue],
            sets: 3,
            reps: "8-12"
        )
        let templates = [
            BlockWeeklyTemplate(id: UUID(), dayName: "Push", focus: "Push", slots: [slot]),
            BlockWeeklyTemplate(id: UUID(), dayName: "Pull", focus: "Pull", slots: [slot]),
            BlockWeeklyTemplate(id: UUID(), dayName: "Legs", focus: "Legs", slots: [slot])
        ]
        let workoutIds = [UUID(), UUID(), UUID()]
        return (anchor, mon, wed, fri, templates, workoutIds)
    }

    static func dynamicState(
        anchor: Date,
        templates: [BlockWeeklyTemplate],
        workoutIds: [UUID],
        calendar: Calendar
    ) -> DynamicProgramState {
        let block = ProgramBlock(
            name: "Block 1",
            focus: BlockFocus(kind: .hypertrophy),
            durationWeeks: 8,
            weeklyTemplates: templates
        )
        let program = DynamicProgram(
            name: "Test",
            blocks: [block],
            defaultSessionsPerWeek: 3,
            preferredWeekdays: [2, 4, 6]
        )
        let materialized = Dictionary(uniqueKeysWithValues: zip(templates.map(\.id), workoutIds))
        return DynamicProgramState(
            program: program,
            anchorDate: anchor,
            materializedTemplateWorkoutIds: materialized
        )
    }

    static func completedSession(
        on day: Date,
        workoutId: UUID,
        name: String,
        calendar: Calendar,
        origin: UUID? = nil
    ) -> WorkoutSession {
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
        let end = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: day)!
        let originRef = origin.map { WorkoutPlanRef.workout($0) }
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: workoutId, name: name, exercises: []),
            startTime: start,
            endTime: end,
            exerciseLogs: [],
            sessionPlanOrigin: originRef ?? .workout(workoutId)
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV5.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
