//
//  DailyAdjustViewModel.swift
//  FitLog
//

import Foundation
import Observation

@Observable @MainActor
final class DailyAdjustViewModel {
    var userNote = ""
    var isLoading = false
    var proposal: DailyAdjustmentProposal?
    var applyResultMessage: String?
    var errorMessage: String?
    var showPaywall = false

    private let router: AIRoutingService

    init(router: AIRoutingService? = nil) {
        // Default args are evaluated in a nonisolated context; resolve `.shared` in the @MainActor body.
        self.router = router ?? .shared
    }

    var availabilityNote: String? {
        router.availabilityBannerText
    }

    func buildContext(
        dataVM: DataManager,
        readinessScore: ReadinessScore?,
        plannedWorkout: Workout?
    ) -> DailyAdjustContextPack {
        let dayKey = TrainingProgramState.dayKey(for: Date())
        let detail: String = {
            guard let plannedWorkout else { return "No workout scheduled" }
            let names = plannedWorkout.exercises.prefix(8).map { dataVM.displayName(for: $0) }.joined(separator: ", ")
            return "\(plannedWorkout.exercises.count) exercises: \(names)"
        }()
        let load = dataVM.trainingLoadMetrics()
        let loadSummary = "72h hard sets \(load.recentHardSets); typical 72h \(Int(load.typicalHardSets72h))"
        return DailyAdjustContextPack(
            dayKey: dayKey,
            readinessScore: readinessScore?.score,
            readinessSummary: readinessScore?.summary ?? "No readiness score yet",
            plannedWorkoutName: plannedWorkout?.name ?? "Unscheduled",
            plannedWorkoutDetail: detail,
            recentLoadSummary: loadSummary,
            userNote: userNote.trimmingCharacters(in: .whitespacesAndNewlines),
            hasDynamicProgram: dataVM.dynamicProgramState != nil
        )
    }

    func generate(
        dataVM: DataManager,
        aiService: AIService,
        entitlementStore: EntitlementStore,
        readinessScore: ReadinessScore?,
        plannedWorkout: Workout?
    ) async {
        guard entitlementStore.hasAccess(to: .aiCoach) else {
            showPaywall = true
            AnalyticsService.shared.track(.aiBlockedByPaywall, properties: ["feature": "daily_adjust"])
            return
        }
        isLoading = true
        errorMessage = nil
        applyResultMessage = nil
        defer { isLoading = false }
        let context = buildContext(dataVM: dataVM, readinessScore: readinessScore, plannedWorkout: plannedWorkout)
        proposal = await router.proposeDailyAdjustment(
            context: context,
            isPremium: true,
            aiService: aiService
        )
    }

    func accept(dataVM: DataManager) {
        guard let proposal else { return }
        let dayKey = TrainingProgramState.dayKey(for: Date())
        applyResultMessage = DailyAdjustApplier.apply(proposal, dataVM: dataVM, dayKey: dayKey)
    }
}
