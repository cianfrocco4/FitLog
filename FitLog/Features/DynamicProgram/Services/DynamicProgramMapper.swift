//
//  DynamicProgramMapper.swift
//  FitLog
//
//  Maps `WorkoutSplitProposal` into `DynamicProgram` / `ProgramBlock` / `BlockWeeklyTemplate`.
//

import Foundation

enum DynamicProgramMapper {
    /// Resolves cardio settings for a block spec, merging global wizard input with per-block overrides.
    static func resolvedCardioConfiguration(
        for spec: DynamicBlockGenerationSpec,
        request: DynamicProgramGenerationRequest,
        defaultPreference: CardioProgramPreference? = nil
    ) -> CardioProgramConfiguration {
        var config = CardioProgramConfiguration.fromSplitInput(request.splitInput)
        if let defaultPreference, config.preference == .none {
            config.preference = defaultPreference
        }
        if let goal = spec.cardioGoal { config.goal = goal }
        if let pref = spec.cardioPreference { config.preference = pref }
        if let count = spec.cardioDedicatedDayCount { config.dedicatedDayCount = count }
        if let minutes = spec.cardioFinisherDurationMinutes {
            config.finisherDurationMinutes = CardioProgramConfiguration.clampedFinisherMinutes(minutes)
        }
        if let zone = spec.cardioFinisherZone { config.finisherZone = zone }
        if let progression = spec.cardioWeeklyProgressionMinutes {
            config.weeklyProgressionMinutes = progression
        }
        switch spec.focus.kind {
        case .endurance:
            config.preference = .dedicatedDays
            config.goal = .enduranceBuilding
        case .hybrid:
            config.preference = .mixed
        default:
            break
        }
        return config
    }

    /// Converts each rotation day in the proposal to a weekly template.
    static func weeklyTemplates(
        from proposal: WorkoutSplitProposal,
        blockFocus: BlockFocus? = nil,
        library: [Exercise] = [],
        configuration: CardioProgramConfiguration = .none
    ) -> [BlockWeeklyTemplate] {
        if blockFocus?.kind == .endurance {
            return CardioProgramTemplates.enduranceWeeklyTemplates(
                sessionsPerWeek: proposal.sessionsPerWeek,
                library: library,
                configuration: configuration
            )
        }
        let base = proposal.workouts.map { day in
            let editable = SplitBuilderEditableDay(from: day, library: library)
            return BlockWeeklyTemplate(
                dayName: editable.name,
                focus: editable.focus,
                slots: editable.slots,
                dayNotes: editable.dayNotes
            )
        }
        var config = configuration
        if blockFocus?.kind == .hybrid { config.preference = .mixed }
        return applyCardioPreference(
            to: base,
            preference: config.preference,
            sessionsPerWeek: proposal.sessionsPerWeek,
            library: library,
            configuration: config
        )
    }

    /// Injects cardio slots or days based on the user's program-builder cardio preference.
    static func applyCardioPreference(
        to templates: [BlockWeeklyTemplate],
        preference: CardioProgramPreference,
        sessionsPerWeek: Int,
        library: [Exercise],
        configuration: CardioProgramConfiguration = .none
    ) -> [BlockWeeklyTemplate] {
        guard preference != .none, !templates.isEmpty else { return templates }

        var result = templates
        var config = configuration
        config.preference = preference

        if preference.includesPostWorkoutFinishers {
            result = result.map { day in
                var copy = day
                let hasCardio = copy.slots.contains { $0.modality == .cardio }
                if !hasCardio {
                    copy.slots.append(CardioProgramTemplates.finisherSlot(library: library, configuration: config))
                }
                return copy
            }
        }

        if preference.includesDedicatedCardioDays {
            let cardioDayCount = min(max(1, config.dedicatedDayCount), 4)
            let dedicatedDays = (0 ..< cardioDayCount).map { index in
                CardioProgramTemplates.dedicatedCardioDay(library: library, index: index, configuration: config)
            }
            if result.count + dedicatedDays.count <= 7 {
                result.append(contentsOf: dedicatedDays)
            } else {
                let replaceCount = min(dedicatedDays.count, result.count)
                let keepCount = result.count - replaceCount
                var updated = Array(result.prefix(keepCount))
                updated.append(contentsOf: dedicatedDays.prefix(replaceCount))
                result = updated
            }
        }

        return result
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

    static func singleBlock(
        from proposal: WorkoutSplitProposal,
        request: DynamicProgramGenerationRequest,
        library: [Exercise] = []
    ) -> DynamicProgram {
        let spec = request.blockSpecs.first ?? DynamicBlockGenerationSpec(title: "Block 1", focus: BlockFocus(kind: .general, emphasisLabel: ""))
        let blockCardio = resolvedCardioConfiguration(for: spec, request: request)
        let templates = weeklyTemplates(
            from: proposal,
            blockFocus: spec.focus,
            library: library,
            configuration: blockCardio
        )
        let block = ProgramBlock(
            name: spec.title.isEmpty ? "Block 1" : spec.title,
            focus: spec.focus,
            durationWeeks: spec.durationWeeks,
            weeklyTemplates: templates,
            progressionStrategy: spec.progressionStrategy,
            isDeloadBlock: spec.isDeloadBlock,
            volumeMultiplier: spec.volumeMultiplier,
            cardioGoal: blockCardio.goal,
            cardioPreference: blockCardio.preference,
            cardioDedicatedDayCount: blockCardio.dedicatedDayCount,
            cardioFinisherDurationMinutes: blockCardio.finisherDurationMinutes,
            cardioFinisherZone: blockCardio.finisherZone,
            cardioWeeklyProgressionMinutes: blockCardio.weeklyProgressionMinutes
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
    static func multiBlock(
        from proposal: WorkoutSplitProposal,
        request: DynamicProgramGenerationRequest,
        library: [Exercise] = []
    ) -> DynamicProgram {
        let cardioPref = CardioProgramPreference.fromStored(request.splitInput.cardioPreference)
        let rawBaseTemplates = weeklyTemplates(
            from: proposal,
            library: library,
            configuration: .none
        )
        let specs = request.blockSpecs
        let effectiveSpecs: [DynamicBlockGenerationSpec] = {
            if specs.isEmpty {
                return [DynamicBlockGenerationSpec(title: "Block 1", focus: BlockFocus(kind: .general, emphasisLabel: ""))]
            }
            return specs
        }()
        let isMultiBlock = effectiveSpecs.count > 1
        let blocks: [ProgramBlock] = effectiveSpecs.map { spec in
            let blockName = spec.title.isEmpty ? spec.focus.displayTitle : spec.title
            let blockCardio = resolvedCardioConfiguration(for: spec, request: request, defaultPreference: cardioPref)
            let templates: [BlockWeeklyTemplate] = switch spec.focus.kind {
            case .endurance:
                CardioProgramTemplates.enduranceWeeklyTemplates(
                    sessionsPerWeek: proposal.sessionsPerWeek,
                    library: library,
                    configuration: blockCardio
                )
            case .hybrid:
                applyCardioPreference(
                    to: duplicateWeeklyTemplates(rawBaseTemplates),
                    preference: .mixed,
                    sessionsPerWeek: proposal.sessionsPerWeek,
                    library: library,
                    configuration: blockCardio
                )
            default:
                applyCardioPreference(
                    to: duplicateWeeklyTemplates(rawBaseTemplates),
                    preference: blockCardio.preference,
                    sessionsPerWeek: proposal.sessionsPerWeek,
                    library: library,
                    configuration: blockCardio
                )
            }
            let prefixedTemplates = ProgramBlockNaming.applyBlockPrefixIfNeeded(
                to: templates,
                blockName: blockName,
                isMultiBlock: isMultiBlock
            )
            return ProgramBlock(
                name: blockName,
                focus: spec.focus,
                durationWeeks: spec.durationWeeks,
                weeklyTemplates: prefixedTemplates,
                progressionStrategy: spec.progressionStrategy,
                isDeloadBlock: spec.isDeloadBlock,
                volumeMultiplier: spec.volumeMultiplier,
                cardioGoal: blockCardio.goal,
                cardioPreference: blockCardio.preference,
                cardioDedicatedDayCount: blockCardio.dedicatedDayCount,
                cardioFinisherDurationMinutes: blockCardio.finisherDurationMinutes,
                cardioFinisherZone: blockCardio.finisherZone,
                cardioWeeklyProgressionMinutes: blockCardio.weeklyProgressionMinutes
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
