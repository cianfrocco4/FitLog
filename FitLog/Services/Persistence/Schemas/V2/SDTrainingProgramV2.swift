//
//  SDTrainingProgramV2.swift
//  FitLog
//

import Foundation
import SwiftData

@Model
final class SDTrainingProgramV2 {
    var sessionsPerWeek: Int = 3
    var preferredWeekdaysData: Data = Data()
    var anchorDayKey: String = ""
    var cyclePhaseOffset: Int = 0
    var skippedCycleTrainingDayKeysData: Data = Data()

    @Relationship(deleteRule: .cascade, inverse: \SDProgramCycleEntryV2.program)
    var cycleEntries: [SDProgramCycleEntryV2] = []

    @Relationship(deleteRule: .cascade, inverse: \SDFrozenPlanDayV2.program)
    var frozenDays: [SDFrozenPlanDayV2] = []

    @Relationship(deleteRule: .cascade, inverse: \SDDayOverrideV2.program)
    var dayOverrides: [SDDayOverrideV2] = []

    @Relationship(deleteRule: .cascade, inverse: \SDWeekOverrideV2.program)
    var weekOverrides: [SDWeekOverrideV2] = []

    init() {}

    func toDomain() -> TrainingProgramState {
        let weekdays = versionedDecode([Int].self, from: preferredWeekdaysData) ?? []
        let skipped = versionedDecode([String].self, from: skippedCycleTrainingDayKeysData) ?? []
        let sortedCycle = cycleEntries.sorted { $0.orderIndex < $1.orderIndex }
        let cycle = sortedCycle.map { $0.toPlanRef() }
        let frozen = Dictionary(
            uniqueKeysWithValues: frozenDays.map { $0.toDomain() }
        )
        let dayOvr = Dictionary(
            uniqueKeysWithValues: dayOverrides.map { $0.toDomain() }
        )
        let weekOvr = Dictionary(
            uniqueKeysWithValues: weekOverrides.map { $0.toDomain() }
        )
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

    static func from(_ p: TrainingProgramState) -> SDTrainingProgramV2 {
        let sd = SDTrainingProgramV2()
        sd.sessionsPerWeek = p.sessionsPerWeek
        sd.preferredWeekdaysData = versionedEncode(p.preferredWeekdays)
        sd.anchorDayKey = p.anchorDayKey
        sd.cyclePhaseOffset = p.cyclePhaseOffset
        sd.skippedCycleTrainingDayKeysData = versionedEncode(p.skippedCycleTrainingDayKeys)
        sd.cycleEntries = p.cycleEntries.enumerated().map { idx, ref in
            SDProgramCycleEntryV2(orderIndex: idx, workoutId: ref.libraryWorkoutId)
        }
        sd.frozenDays = p.frozenCalendarDays.map { SDFrozenPlanDayV2.from(key: $0.key, day: $0.value) }
        sd.dayOverrides = p.dayOverrides.map { SDDayOverrideV2.from(key: $0.key, override: $0.value) }
        sd.weekOverrides = p.weekOverrides.map { SDWeekOverrideV2.from(key: $0.key, override: $0.value) }
        return sd
    }
}
