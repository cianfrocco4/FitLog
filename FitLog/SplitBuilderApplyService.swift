//
//  SplitBuilderApplyService.swift
//  FitLog
//
//  Shared conversion/apply helpers so AI and manual split builders persist the
//  same flexible workout shape.
//

import Foundation

enum SplitBuilderApplyService {
    static func proposal(
        from days: [SplitBuilderEditableDay],
        rationale: String,
        sessionsPerWeek: Int,
        preferredWeekdays: [Int]
    ) -> WorkoutSplitProposal {
        WorkoutSplitProposal(
            rationale: rationale,
            sessionsPerWeek: min(max(1, sessionsPerWeek), 7),
            preferredWeekdays: preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted(),
            workouts: days.map { $0.toProposalDay() }
        )
    }

    @MainActor
    static func apply(
        days: [SplitBuilderEditableDay],
        dataVM: DataManager,
        sessionsPerWeek: Int,
        preferredWeekdays: [Int],
        updateTrainingProgram: Bool,
        rationale: String,
        anchorDate: Date = Date()
    ) -> WorkoutSplitProposal {
        let p = proposal(
            from: days,
            rationale: rationale,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: preferredWeekdays
        )
        dataVM.applyWorkoutSplitProposal(
            p,
            updateTrainingProgram: updateTrainingProgram,
            anchorDate: anchorDate
        )
        return p
    }
}

