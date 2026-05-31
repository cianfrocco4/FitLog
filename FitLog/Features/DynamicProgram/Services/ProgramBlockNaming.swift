//
//  ProgramBlockNaming.swift
//  FitLog
//
//  Phase-aware workout day names for multi-block programs.
//

import Foundation

enum ProgramBlockNaming {
    /// Short label used in prefixed workout names (e.g. "Phase 1: Build muscle" → "Phase 1").
    static func shortBlockLabel(_ blockName: String) -> String {
        let trimmed = blockName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Phase" }
        if let colon = trimmed.firstIndex(of: ":") {
            let head = trimmed[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            if !head.isEmpty { return head }
        }
        return trimmed
    }

    /// Returns `"BlockLabel: DayName"` when `isMultiBlock`; otherwise returns the day name unchanged.
    static func materializedWorkoutName(dayName: String, blockName: String, isMultiBlock: Bool) -> String {
        let day = dayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isMultiBlock else {
            return day.isEmpty ? "Workout" : day
        }
        return prefixedDayName(dayName: day, blockName: blockName)
    }

    static func prefixedDayName(dayName: String, blockName: String) -> String {
        let day = dayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let block = shortBlockLabel(blockName)
        guard !block.isEmpty else { return day.isEmpty ? "Workout" : day }
        guard !day.isEmpty else { return block }
        let prefix = "\(block): "
        if day.lowercased().hasPrefix(prefix.lowercased()) { return day }
        return "\(block): \(day)"
    }

    /// Applies block prefix to weekly template day names for multi-block programs.
    static func applyBlockPrefixIfNeeded(
        to templates: [BlockWeeklyTemplate],
        blockName: String,
        isMultiBlock: Bool
    ) -> [BlockWeeklyTemplate] {
        guard isMultiBlock else { return templates }
        return templates.map { template in
            BlockWeeklyTemplate(
                id: template.id,
                dayName: prefixedDayName(dayName: template.dayName, blockName: blockName),
                focus: template.focus,
                slots: template.slots,
                dayNotes: template.dayNotes
            )
        }
    }
}
