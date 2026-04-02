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
        var program = TrainingProgramState(
            cycleEntries: [
                .concreteWorkout(idPush),
                .concreteWorkout(idPull),
                .concreteWorkout(idLegs)
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
        #expect(engine.resolve(date: mon, program: program) == .workout(.concreteWorkout(idPush)))
        #expect(engine.resolve(date: wed, program: program) == .workout(.concreteWorkout(idPull)))
        #expect(engine.resolve(date: fri, program: program) == .workout(.concreteWorkout(idLegs)))
    }

    @Test func trainingScheduleEngine_dayOverrideBeatsDefault() {
        let cal = Calendar(identifier: .gregorian)
        let engine = TrainingScheduleEngine(calendar: cal)
        let idA = UUID(), idB = UUID()
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let mon = anchor
        let dayKey = TrainingProgramState.dayKey(for: mon, calendar: cal)
        var program = TrainingProgramState(
            cycleEntries: [.concreteWorkout(idA)],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 3, 4],
            anchorDayKey: TrainingProgramState.dayKey(for: anchor, calendar: cal),
            dayOverrides: [dayKey: ScheduleDayOverride(intent: .workout, workoutId: idB)],
            weekOverrides: [:]
        )
        #expect(engine.resolve(date: mon, program: program) == .workout(.concreteWorkout(idB)))
    }

    @Test func trainingScheduleEngine_dayOverrideSupportsSlotTemplate() {
        let cal = Calendar(identifier: .gregorian)
        let engine = TrainingScheduleEngine(calendar: cal)
        let idTemplate = UUID()
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 16))!
        let mon = anchor
        let dayKey = TrainingProgramState.dayKey(for: mon, calendar: cal)
        let program = TrainingProgramState(
            cycleEntries: [.concreteWorkout(UUID())],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 3, 4],
            anchorDayKey: TrainingProgramState.dayKey(for: anchor, calendar: cal),
            dayOverrides: [dayKey: ScheduleDayOverride(intent: .workout, planRef: .slotTemplate(idTemplate))],
            weekOverrides: [:]
        )
        #expect(engine.resolve(date: mon, program: program) == .workout(.slotTemplate(idTemplate)))
    }

    @Test func scheduleDayOverride_encodesRoundTripWithTemplate() throws {
        let original = ScheduleDayOverride(intent: .workout, planRef: .slotTemplate(UUID()))
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
        let original = FrozenPlanDay(resolved: .workout(.concreteWorkout(id)))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FrozenPlanDay.self, from: data)
        #expect(decoded == original)
        #expect(decoded.asResolved() == .workout(.concreteWorkout(id)))
    }

    @Test func workout_decodesLegacyJSONWithoutIsPinned() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Legacy","exercises":[]}
        """.data(using: .utf8)!
        let w = try JSONDecoder().decode(Workout.self, from: json)
        #expect(w.isPinned == false)
    }

    @Test func workout_encodesRoundTripWithIsPinned() throws {
        let w = Workout(id: UUID(), name: "Pinned", exercises: [], isPinned: true)
        let data = try JSONEncoder().encode(w)
        let decoded = try JSONDecoder().decode(Workout.self, from: data)
        #expect(decoded.isPinned == true)
        #expect(decoded.name == "Pinned")
    }

    @Test func workoutTemplate_decodesLegacyJSONWithoutIsPinned() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"T","slots":[]}
        """.data(using: .utf8)!
        let t = try JSONDecoder().decode(WorkoutTemplate.self, from: json)
        #expect(t.isPinned == false)
    }

    @Test func homeListOrdering_keepsPinnedBeforeUnpinned() {
        let idA = UUID(), idB = UUID(), idC = UUID()
        let wA = Workout(id: idA, name: "a", exercises: [], isPinned: false)
        let wB = Workout(id: idB, name: "b", exercises: [], isPinned: true)
        let wC = Workout(id: idC, name: "c", exercises: [], isPinned: false)
        let program = TrainingProgramState.empty(anchorDayKey: "day")
        let ordered = HomeListOrdering.orderWorkouts([wA, wC, wB], program: program, sessions: [])
        #expect(ordered.map(\.id) == [idB, idA, idC])
    }

    @Test func homeListOrdering_splitDisplayOrderFollowsCycleEntries() {
        let id1 = UUID(), id2 = UUID(), id3 = UUID()
        let w1 = Workout(id: id1, name: "A", exercises: [])
        let w2 = Workout(id: id2, name: "B", exercises: [])
        let w3 = Workout(id: id3, name: "C", exercises: [])
        var program = TrainingProgramState.empty(anchorDayKey: "2026-01-01")
        program.cycleEntries = [.concreteWorkout(id3), .concreteWorkout(id1)]
        let ordered = HomeListOrdering.workoutsInSplitDisplayOrder([w1, w2, w3], program: program)
        #expect(ordered.map(\.id) == [id3, id1])
    }

    @Test func homeListOrdering_splitIdsIgnoreCalendarOverrides() {
        let idCycle = UUID(), idOverride = UUID()
        var program = TrainingProgramState.empty(anchorDayKey: "2026-01-01")
        program.cycleEntries = [.concreteWorkout(idCycle)]
        program.dayOverrides["2026-03-01"] = ScheduleDayOverride(intent: .workout, planRef: .concreteWorkout(idOverride))
        let splitIds = HomeListOrdering.splitConcreteWorkoutIds(from: program)
        #expect(splitIds == Set([idCycle]))
    }
}
