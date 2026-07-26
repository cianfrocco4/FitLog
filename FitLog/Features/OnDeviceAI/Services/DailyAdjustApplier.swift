//
//  DailyAdjustApplier.swift
//  FitLog
//
//  Applies accepted DailyAdjustmentProposal changes to today's plan.
//

import Foundation

enum DailyAdjustApplier {
    @MainActor
    static func apply(
        _ proposal: DailyAdjustmentProposal,
        dataVM: DataManager,
        dayKey: String
    ) -> String {
        var applied: [String] = []
        for change in proposal.changes {
            switch change.kind {
            case .makeLighter:
                if dataVM.dynamicProgramState != nil {
                    dataVM.setDynamicProgramBusyDay(dayKey: dayKey, isBusy: true)
                    applied.append("Marked today as a lighter/flex day.")
                } else {
                    applied.append("Noted lighter effort — no dynamic program to auto-flex; train with reduced intensity.")
                }
            case .markRest:
                dataVM.setTrainingDayOverride(dayKey: dayKey, intent: .rest, planRef: nil)
                applied.append("Today marked as rest in your plan.")
            case .keepAsPlanned:
                applied.append("Kept today's plan as scheduled.")
            case .swapFocusNote:
                applied.append(change.detail)
            }
        }
        if applied.isEmpty {
            return "No plan changes were applied."
        }
        return applied.joined(separator: " ")
    }
}
