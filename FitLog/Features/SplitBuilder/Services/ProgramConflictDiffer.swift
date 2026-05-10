//
//  ProgramConflictDiffer.swift
//  FitLog
//
//  Compares proposed split to current training program to show what will change (Task 24).
//

import Foundation

struct SplitConflictDiff {
    struct TemplateDecision: Identifiable {
        let id: UUID
        let templateName: String
        var keepExisting: Bool
    }

    var willReplaceCycle: Bool
    var currentCycleCount: Int
    var proposedCycleCount: Int
    var templateDecisions: [TemplateDecision]
    var existingTemplatesKept: Int
    var newTemplatesCreated: Int
}

enum ProgramConflictDiffer {
    @MainActor
    static func diff(
        proposedDays: [SplitBuilderEditableDay],
        currentProgram: TrainingProgramState,
        currentWorkouts: [Workout]
    ) -> SplitConflictDiff {
        let willReplaceCycle = !currentProgram.cycleEntries.isEmpty
        let currentCycleCount = currentProgram.cycleEntries.count

        var decisions: [SplitConflictDiff.TemplateDecision] = []
        for day in proposedDays {
            let templateName = day.name
            // Check if a similar template already exists
            let existingMatch = currentWorkouts.first { w in
                w.name.lowercased() == templateName.lowercased()
            }
            decisions.append(
                .init(
                    id: UUID(),
                    templateName: templateName,
                    keepExisting: existingMatch != nil
                )
            )
        }

        let kept = decisions.filter { $0.keepExisting }.count
        let new = decisions.filter { !$0.keepExisting }.count

        return SplitConflictDiff(
            willReplaceCycle: willReplaceCycle,
            currentCycleCount: currentCycleCount,
            proposedCycleCount: proposedDays.count,
            templateDecisions: decisions,
            existingTemplatesKept: kept,
            newTemplatesCreated: new
        )
    }

    /// Apply user decisions: if `keepExisting == true`, reference the existing workout; otherwise create a new one.
    @MainActor
    static func applyWithDecisions(
        days: [SplitBuilderEditableDay],
        decisions: [SplitConflictDiff.TemplateDecision],
        dataVM: DataManager,
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        updateTrainingProgram: Bool,
        rationale: String,
        anchorDate: Date
    ) -> WorkoutSplitProposal {
        // For now, just delegate to the standard apply flow.
        // Future: filter days based on decisions (e.g., keep existing workout IDs).
        return SplitBuilderApplyService.apply(
            days: days,
            dataVM: dataVM,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays,
            updateTrainingProgram: updateTrainingProgram,
            rationale: rationale,
            anchorDate: anchorDate
        )
    }
}
