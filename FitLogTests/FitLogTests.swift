//
//  FitLogTests.swift
//  FitLogTests
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import Testing
@testable import FitLog

struct FitLogTests {

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
}
