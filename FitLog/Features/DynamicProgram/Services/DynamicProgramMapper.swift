//
//  DynamicProgramMapper.swift
//  FitLog
//
//  Maps `WorkoutSplitProposal` into `DynamicProgram` / `ProgramBlock` / `BlockWeeklyTemplate`.
//

import Foundation

enum DynamicProgramMapper {
    /// Converts each rotation day in the proposal to a weekly template.
    static func weeklyTemplates(from proposal: WorkoutSplitProposal) -> [BlockWeeklyTemplate] {
        proposal.workouts.map { day in
            let editable = SplitBuilderEditableDay(from: day)
            return BlockWeeklyTemplate(
                dayName: editable.name,
                focus: editable.focus,
                slots: editable.slots,
                dayNotes: editable.dayNotes
            )
        }
    }

    /// Fresh copies with new template and slot ids (for additional blocks).
    static func duplicateWeeklyTemplates(_ templates: [BlockWeeklyTemplate]) -> [BlockWeeklyTemplate] {
        templates.map { t in
            let oldIds = t.slots.map(\.id)
            let freshSlots = t.slots.map { $0.withNewSlotId() }
            let idMap = Dictionary(uniqueKeysWithValues: zip(oldIds, freshSlots.map(\.id)))
            let remappedSlots = freshSlots.map { slot in
                slot.remappingGroupingPartnerIds(using: idMap)
            }
            return BlockWeeklyTemplate(
                id: UUID(),
                dayName: t.dayName,
                focus: t.focus,
                slots: remappedSlots,
                dayNotes: t.dayNotes
            )
        }
    }

    static func singleBlock(from proposal: WorkoutSplitProposal, request: DynamicProgramGenerationRequest) -> DynamicProgram {
        let spec = request.blockSpecs.first ?? DynamicBlockGenerationSpec(title: "Block 1", focus: BlockFocus(kind: .general, emphasisLabel: ""))
        let templates = weeklyTemplates(from: proposal)
        let block = ProgramBlock(
            name: spec.title.isEmpty ? "Block 1" : spec.title,
            focus: spec.focus,
            durationWeeks: spec.durationWeeks,
            weeklyTemplates: templates,
            progressionStrategy: spec.progressionStrategy,
            isDeloadBlock: spec.isDeloadBlock,
            volumeMultiplier: spec.volumeMultiplier
        )
        let name = request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My program" : request.programName
        return DynamicProgram(
            name: name,
            blocks: [block],
            defaultSessionsPerWeek: proposal.sessionsPerWeek,
            preferredWeekdays: proposal.preferredWeekdays,
            busyDayPolicy: request.busyDayPolicy
        )
    }

    /// Reuses the same rotation templates for each block (focus / duration / progression differ per spec).
    static func multiBlock(from proposal: WorkoutSplitProposal, request: DynamicProgramGenerationRequest) -> DynamicProgram {
        let baseTemplates = weeklyTemplates(from: proposal)
        let specs = request.blockSpecs
        let effectiveSpecs: [DynamicBlockGenerationSpec] = {
            if specs.isEmpty {
                return [DynamicBlockGenerationSpec(title: "Block 1", focus: BlockFocus(kind: .general, emphasisLabel: ""))]
            }
            return specs
        }()
        let blocks: [ProgramBlock] = effectiveSpecs.map { spec in
            ProgramBlock(
                name: spec.title.isEmpty ? spec.focus.displayTitle : spec.title,
                focus: spec.focus,
                durationWeeks: spec.durationWeeks,
                weeklyTemplates: duplicateWeeklyTemplates(baseTemplates),
                progressionStrategy: spec.progressionStrategy,
                isDeloadBlock: spec.isDeloadBlock,
                volumeMultiplier: spec.volumeMultiplier
            )
        }
        let name = request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My program" : request.programName
        return DynamicProgram(
            name: name,
            blocks: blocks,
            defaultSessionsPerWeek: proposal.sessionsPerWeek,
            preferredWeekdays: proposal.preferredWeekdays,
            busyDayPolicy: request.busyDayPolicy
        )
    }

    // MARK: - Local preset fallback (no AI)

    /// Builds a split proposal from library-backed presets when the AI client is not configured.
    static func localWorkoutSplitProposal(
        from structured: WorkoutSplitBuilderStructuredInput,
        library: [Exercise]
    ) -> WorkoutSplitProposal {
        let preset = manualPreset(fromSplitPreference: structured.splitPreference)
        let variationMode = SplitBuilderVariationMode(rawValue: structured.variationMode) ?? .balanced
        let days = SplitBuilderSharedFactory.presetDays(
            preset: preset,
            count: structured.sessionsPerWeek,
            variationMode: variationMode,
            customRotationLength: structured.desiredWorkoutRotationLength,
            library: library
        )
        let workouts = days.map { $0.toProposalDay() }
        let sessions = min(max(1, structured.sessionsPerWeek), 7)
        let preferred = structured.preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        return WorkoutSplitProposal(
            rationale: "Built from FitLog’s local rotation presets (no AI). You can edit templates after saving.",
            sessionsPerWeek: sessions,
            preferredWeekdays: preferred,
            workouts: workouts
        )
    }

    private static func manualPreset(fromSplitPreference text: String) -> SplitBuilderManualPreset {
        let t = text.lowercased()
        if t.contains("push") && t.contains("pull") { return .pushPullLegs }
        if t.contains("upper") && t.contains("lower") { return .upperLower }
        if t.contains("full") { return .fullBody }
        if t.contains("bro") || t.contains("muscle group") { return .broSplit }
        return .pushPullLegs
    }

    /// Blank rotation templates for manual program building (no AI, no preset exercises).
    static func blankProgram(from request: DynamicProgramGenerationRequest) -> DynamicProgram {
        let sessions = min(max(1, request.splitInput.sessionsPerWeek), 7)
        let variationMode = SplitBuilderVariationMode(rawValue: request.splitInput.variationMode) ?? .balanced
        let rotationCount = variationMode.targetRotationLength(
            sessionsPerWeek: sessions,
            splitPreferenceText: request.splitInput.splitPreference,
            customCount: request.splitInput.desiredWorkoutRotationLength
        )
        let blankTemplates: [BlockWeeklyTemplate] = (0 ..< rotationCount).map { i in
            BlockWeeklyTemplate(dayName: "Day \(i + 1)", focus: "", slots: [])
        }
        let specs = request.blockSpecs.isEmpty
            ? [DynamicBlockGenerationSpec(title: "Block 1", focus: BlockFocus(kind: .general, emphasisLabel: ""))]
            : request.blockSpecs
        let blocks: [ProgramBlock] = specs.map { spec in
            ProgramBlock(
                name: spec.title.isEmpty ? spec.focus.displayTitle : spec.title,
                focus: spec.focus,
                durationWeeks: spec.durationWeeks,
                weeklyTemplates: duplicateWeeklyTemplates(blankTemplates),
                progressionStrategy: spec.progressionStrategy,
                isDeloadBlock: spec.isDeloadBlock,
                volumeMultiplier: spec.volumeMultiplier
            )
        }
        let name = request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My program" : request.programName
        let preferred = request.splitInput.preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        return DynamicProgram(
            name: name,
            blocks: blocks,
            defaultSessionsPerWeek: sessions,
            preferredWeekdays: preferred,
            busyDayPolicy: request.busyDayPolicy,
            generatedWithAI: false
        )
    }
}
