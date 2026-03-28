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
}
