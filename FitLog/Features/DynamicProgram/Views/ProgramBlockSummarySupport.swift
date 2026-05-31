//
//  ProgramBlockSummarySupport.swift
//  FitLog
//
//  Aggregates block/template stats for program review summary cards.
//

import Foundation

enum ProgramBlockSummarySupport {
    struct BlockStats: Equatable, Sendable {
        let dayCount: Int
        let slotCount: Int
        let strengthSetCount: Int
        let cardioSlotCount: Int
        let dayNamesLine: String
        let topExercisePreview: String
        let estimatedCardioMinutes: Int
    }

    static func stats(for block: ProgramBlock, warnings: [SplitProposalProgramWarning] = []) -> BlockStats {
        let templates = block.weeklyTemplates
        let slots = templates.flatMap(\.slots)
        let strengthSets = slots.filter { $0.modality != .cardio }.reduce(0) { $0 + $1.sets }
        let cardioSlots = slots.filter { $0.modality == .cardio }.count
        let dayNames = templates.map(\.dayName).filter { !$0.isEmpty }
        let dayNamesLine = dayNames.isEmpty ? "No days" : dayNames.joined(separator: " · ")

        let exerciseNames = slots.prefix(12).map { slot -> String in
            if let n = slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                return n
            }
            let lab = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return lab.isEmpty ? "Slot" : lab
        }
        let topExercisePreview = exerciseNames.prefix(4).joined(separator: ", ")

        let config = CardioProgramConfiguration(
            goal: block.cardioGoal ?? .generalHealth,
            preference: block.cardioPreference ?? .none,
            dedicatedDayCount: block.cardioDedicatedDayCount ?? 2,
            finisherDurationMinutes: block.cardioFinisherDurationMinutes ?? 10,
            finisherZone: block.cardioFinisherZone ?? .zone2,
            weeklyProgressionMinutes: block.cardioWeeklyProgressionMinutes ?? 5
        )
        _ = warnings

        return BlockStats(
            dayCount: templates.count,
            slotCount: slots.count,
            strengthSetCount: strengthSets,
            cardioSlotCount: cardioSlots,
            dayNamesLine: dayNamesLine,
            topExercisePreview: topExercisePreview,
            estimatedCardioMinutes: config.estimatedWeeklyMinutes
        )
    }

    static func stats(
        forBlockIndex index: Int,
        editableDays: [[SplitBuilderEditableDay]],
        program: DynamicProgram,
        warnings: [SplitProposalProgramWarning]
    ) -> BlockStats {
        guard program.blocks.indices.contains(index),
              editableDays.indices.contains(index) else {
            return BlockStats(
                dayCount: 0,
                slotCount: 0,
                strengthSetCount: 0,
                cardioSlotCount: 0,
                dayNamesLine: "",
                topExercisePreview: "",
                estimatedCardioMinutes: 0
            )
        }
        let block = program.blocks[index]
        let days = editableDays[index]
        let templates = days.map { day in
            BlockWeeklyTemplate(id: day.id, dayName: day.name, focus: day.focus, slots: day.slots, dayNotes: day.dayNotes)
        }
        var copy = block
        copy.weeklyTemplates = templates
        return stats(for: copy, warnings: warnings)
    }
}
