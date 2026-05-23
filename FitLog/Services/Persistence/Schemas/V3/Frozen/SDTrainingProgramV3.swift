//
//  SDTrainingProgramV3.swift
//  FitLog
//
//  Frozen training program graph for schema 3.0.0 (cycle entries reference SDWorkoutV3).
//

import Foundation
import SwiftData

@Model
final class SDTrainingProgramV3 {
    var sessionsPerWeek: Int = 3
    var preferredWeekdaysData: Data = Data()
    var anchorDayKey: String = ""
    var cyclePhaseOffset: Int = 0
    var skippedCycleTrainingDayKeysData: Data = Data()

    @Relationship(deleteRule: .cascade, inverse: \SDProgramCycleEntryV3.program)
    var cycleEntries: [SDProgramCycleEntryV3] = []

    @Relationship(deleteRule: .cascade, inverse: \SDFrozenPlanDayV3.program)
    var frozenDays: [SDFrozenPlanDayV3] = []

    @Relationship(deleteRule: .cascade, inverse: \SDDayOverrideV3.program)
    var dayOverrides: [SDDayOverrideV3] = []

    @Relationship(deleteRule: .cascade, inverse: \SDWeekOverrideV3.program)
    var weekOverrides: [SDWeekOverrideV3] = []

    init() {}

    func toDomain() -> TrainingProgramState {
        let weekdays = versionedDecode([Int].self, from: preferredWeekdaysData) ?? []
        let skipped = versionedDecode([String].self, from: skippedCycleTrainingDayKeysData) ?? []
        let sortedCycle = cycleEntries.sorted { $0.orderIndex < $1.orderIndex }
        let cycle = sortedCycle.map { $0.toPlanRef() }
        let frozen = Dictionary(uniqueKeysWithValues: frozenDays.map { $0.toDomain() })
        let dayOvr = Dictionary(uniqueKeysWithValues: dayOverrides.map { $0.toDomain() })
        let weekOvr = Dictionary(uniqueKeysWithValues: weekOverrides.map { $0.toDomain() })
        return TrainingProgramState(
            cycleEntries: cycle,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: weekdays,
            anchorDayKey: anchorDayKey,
            cyclePhaseOffset: cyclePhaseOffset,
            skippedCycleTrainingDayKeys: skipped,
            dayOverrides: dayOvr,
            weekOverrides: weekOvr,
            frozenCalendarDays: frozen
        )
    }
}
