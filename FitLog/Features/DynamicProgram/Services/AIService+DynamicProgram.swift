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
        exerciseLibrary: [Exercise]
    ) async throws -> DynamicProgram {
        let multi = request.isPeriodized && request.blockSpecs.count > 1

        if !isConfigured {
            let proposal = DynamicProgramMapper.localWorkoutSplitProposal(from: request.splitInput, library: exerciseLibrary)
            if multi {
                return DynamicProgramMapper.multiBlock(from: proposal, request: request)
            }
            return DynamicProgramMapper.singleBlock(from: proposal, request: request)
        }

        if multi {
            return try await generateDynamicProgramMultiBlockAI(
                request: request,
                allowedExerciseNames: allowedExerciseNames,
                existingWorkoutTemplateNames: existingWorkoutTemplateNames
            )
        }

        let proposal = try await generateWorkoutSplitProposal(
            structured: request.splitInput,
            allowedExerciseNames: allowedExerciseNames,
            existingWorkoutTemplateNames: existingWorkoutTemplateNames
        )
        return DynamicProgramMapper.singleBlock(from: proposal, request: request)
    }

    private func generateDynamicProgramMultiBlockAI(
        request: DynamicProgramGenerationRequest,
        allowedExerciseNames: [String],
        existingWorkoutTemplateNames: [String]
    ) async throws -> DynamicProgram {
        var blocks: [ProgramBlock] = []
        blocks.reserveCapacity(request.blockSpecs.count)
        var sessionsPerWeek = request.splitInput.sessionsPerWeek
        var preferredWeekdays: [Int] = request.splitInput.preferredWeekdays

        for spec in request.blockSpecs {
            var structured = request.splitInput
            let blockNote = """
            [Block phase — follow strictly]
            Block title: \(spec.title)
            Focus: \(spec.focus.displayTitle)
            Planned weeks in phase: \(spec.durationWeeks)
            Progression style (enum): \(spec.progressionStrategy.rawValue)
            Volume multiplier: \(spec.volumeMultiplier)
            Deload block: \(spec.isDeloadBlock ? "yes" : "no")
            """
            if let existing = structured.adjustmentInstruction, !existing.isEmpty {
                structured.adjustmentInstruction = blockNote + "\n\n" + existing
            } else {
                structured.adjustmentInstruction = blockNote
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
            let program = DynamicProgramMapper.singleBlock(from: proposal, request: singleRequest)
            guard let block = program.blocks.first else {
                throw AIServiceError.invalidResponse
            }
            blocks.append(block)
        }

        let name = request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My program" : request.programName
        return DynamicProgram(
            name: name,
            blocks: blocks,
            defaultSessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            busyDayPolicy: request.busyDayPolicy
        )
    }
}
