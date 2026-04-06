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
}
