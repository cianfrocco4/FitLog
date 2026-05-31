//
//  AIService+DynamicProgram.swift
//
//  Bridges split AI (`WorkoutSplitProposal`) into `DynamicProgram` (1 or N blocks).
//

import Foundation

extension AIService {
    /// Runs the split proposal pipeline (AI when configured, otherwise local presets), then materializes a `DynamicProgram`.
    /// Multi-block + AI: one proposal per block with block-specific `adjustmentInstruction` for variation.
    func generateDynamicProgram(
        request: DynamicProgramGenerationRequest,
        allowedExerciseNames: [String],
        existingWorkoutTemplateNames: [String],
        exerciseLibrary: [Exercise],
        onBlockProgress: ((Int, Int) -> Void)? = nil
    ) async throws -> DynamicProgram {
        let multi = request.isPeriodized && request.blockSpecs.count > 1

        if !isConfigured {
            let proposal = DynamicProgramMapper.localWorkoutSplitProposal(from: request.splitInput, library: exerciseLibrary)
            var program: DynamicProgram
            if multi {
                program = DynamicProgramMapper.multiBlock(from: proposal, request: request, library: exerciseLibrary)
            } else {
                program = DynamicProgramMapper.singleBlock(from: proposal, request: request, library: exerciseLibrary)
            }
            program.generatedWithAI = false
            return program
        }

        if multi {
            var program = try await generateDynamicProgramMultiBlockAI(
                request: request,
                allowedExerciseNames: allowedExerciseNames,
                existingWorkoutTemplateNames: existingWorkoutTemplateNames,
                exerciseLibrary: exerciseLibrary,
                onBlockProgress: onBlockProgress
            )
            program.generatedWithAI = true
            return program
        }

        let proposal = try await generateWorkoutSplitProposal(
            structured: request.splitInput,
            allowedExerciseNames: allowedExerciseNames,
            existingWorkoutTemplateNames: existingWorkoutTemplateNames
        )
        var program = DynamicProgramMapper.singleBlock(from: proposal, request: request, library: exerciseLibrary)
        program.generatedWithAI = true
        return program
    }

    private func generateDynamicProgramMultiBlockAI(
        request: DynamicProgramGenerationRequest,
        allowedExerciseNames: [String],
        existingWorkoutTemplateNames: [String],
        exerciseLibrary: [Exercise],
        onBlockProgress: ((Int, Int) -> Void)? = nil
    ) async throws -> DynamicProgram {
        var blocks: [ProgramBlock] = []
        blocks.reserveCapacity(request.blockSpecs.count)
        var sessionsPerWeek = request.splitInput.sessionsPerWeek
        var preferredWeekdays: [Int] = request.splitInput.preferredWeekdays

        let totalBlocks = request.blockSpecs.count
        for (index, spec) in request.blockSpecs.enumerated() {
            onBlockProgress?(index + 1, totalBlocks)
            var structured = request.splitInput
            let blockLabel = ProgramBlockNaming.shortBlockLabel(spec.title.isEmpty ? spec.focus.displayTitle : spec.title)
            let blockNote = """
            [Block phase — follow strictly]
            Block title: \(spec.title)
            Focus: \(spec.focus.displayTitle)
            Planned weeks in phase: \(spec.durationWeeks)
            Progression style (enum): \(spec.progressionStrategy.rawValue)
            Volume multiplier: \(spec.volumeMultiplier)
            Deload block: \(spec.isDeloadBlock ? "yes" : "no")
            Workout day naming: prefix each workouts[].name with "\(blockLabel): " (e.g. "\(blockLabel): Push A") so phases stay distinct.
            """
            let blockCardio = DynamicProgramMapper.resolvedCardioConfiguration(for: spec, request: request)
            let cardioNote = cardioAdjustmentNote(for: blockCardio)
            let combinedNote = blockNote + "\n\n" + cardioNote
            if let existing = structured.adjustmentInstruction, !existing.isEmpty {
                structured.adjustmentInstruction = combinedNote + "\n\n" + existing
            } else {
                structured.adjustmentInstruction = combinedNote
            }

            let proposal = try await generateWorkoutSplitProposal(
                structured: structured,
                allowedExerciseNames: allowedExerciseNames,
                existingWorkoutTemplateNames: existingWorkoutTemplateNames
            )
            if blocks.isEmpty {
                sessionsPerWeek = proposal.sessionsPerWeek
                preferredWeekdays = proposal.preferredWeekdays
            }
            let singleRequest = DynamicProgramGenerationRequest(
                splitInput: request.splitInput,
                programName: request.programName,
                isPeriodized: false,
                blockSpecs: [spec],
                busyDayPolicy: request.busyDayPolicy
            )
            let program = DynamicProgramMapper.singleBlock(from: proposal, request: singleRequest, library: exerciseLibrary)
            guard let block = program.blocks.first else {
                throw AIServiceError.invalidResponse
            }
            var prefixedBlock = block
            if totalBlocks > 1 {
                prefixedBlock.weeklyTemplates = ProgramBlockNaming.applyBlockPrefixIfNeeded(
                    to: block.weeklyTemplates,
                    blockName: block.name,
                    isMultiBlock: true
                )
            }
            blocks.append(prefixedBlock)
        }

        let name = request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My program" : request.programName
        return DynamicProgram(
            name: name,
            blocks: blocks,
            defaultSessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            busyDayPolicy: request.busyDayPolicy,
            generatedWithAI: true
        )
    }

    private func cardioAdjustmentNote(for config: CardioProgramConfiguration) -> String {
        guard config.preference != .none else {
            return "Cardio: none for this phase — strength only."
        }
        var lines: [String] = [
            "Cardio goal: \(config.goal.rawValue)",
            "Cardio integration: \(config.preference.rawValue)",
        ]
        if config.preference.includesPostWorkoutFinishers {
            lines.append("Post-workout finisher: \(config.finisherDurationMinutes) min at \(config.finisherZone.displayName).")
        }
        if config.preference.includesDedicatedCardioDays {
            lines.append("Dedicated cardio days per week: \(config.dedicatedDayCount). Vary steady, tempo, intervals, or sport-specific work.")
        }
        switch config.goal {
        case .fatLoss:
            lines.append("Prefer HIIT, EMOM, or tempo finishers; keep total session time realistic.")
        case .enduranceBuilding, .racePrep:
            lines.append("Include progressive duration or interval volume; label slots clearly (Zone 2, Tempo, Intervals).")
        case .activeRecovery:
            lines.append("Keep intensity low (Zone 1–2); no hard intervals unless user notes say otherwise.")
        case .generalHealth:
            lines.append("Favor easy steady cardio; optional short finishers after lifting.")
        }
        return lines.joined(separator: "\n")
    }
}
