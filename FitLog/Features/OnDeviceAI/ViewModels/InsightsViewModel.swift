//
//  InsightsViewModel.swift
//  FitLog
//

import Foundation
import Observation

@Observable @MainActor
final class InsightsViewModel {
    var insight: WeeklyInsight?
    var isLoading = false
    var showPaywall = false
    var errorMessage: String?

    private let router: AIRoutingService

    init(router: AIRoutingService? = nil) {
        // Default args are evaluated in a nonisolated context; resolve `.shared` in the @MainActor body.
        self.router = router ?? .shared
    }

    func loadCachedOrGenerate(
        dataVM: DataManager,
        aiService: AIService,
        entitlementStore: EntitlementStore,
        readinessTrendSummaries: [String] = []
    ) async {
        let weekKey = WeeklyInsightCache.weekKey()
        if let cached = WeeklyInsightCache.load(weekKey: weekKey) {
            insight = cached
            return
        }
        await regenerate(
            dataVM: dataVM,
            aiService: aiService,
            entitlementStore: entitlementStore,
            readinessTrendSummaries: readinessTrendSummaries
        )
    }

    func regenerate(
        dataVM: DataManager,
        aiService: AIService,
        entitlementStore: EntitlementStore,
        readinessTrendSummaries: [String] = []
    ) async {
        guard entitlementStore.hasAccess(to: .aiCoach) else {
            showPaywall = true
            insight = AIRoutingService.placeholderInsight(weekKey: WeeklyInsightCache.weekKey(), route: .heuristic)
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let weekKey = WeeklyInsightCache.weekKey()
        let context = Self.contextText(dataVM: dataVM, readinessTrendSummaries: readinessTrendSummaries)
        let result = await router.proposeWeeklyInsight(
            weekKey: weekKey,
            contextText: context,
            isPremium: true,
            aiService: aiService
        )
        insight = result
        WeeklyInsightCache.save(result)
    }

    static func contextText(dataVM: DataManager, readinessTrendSummaries: [String]) -> String {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let sessions = dataVM.completedSessions.filter { session in
            guard let end = session.endTime else { return false }
            return end >= weekStart
        }
        let names = sessions.prefix(12).map(\.workout.name).joined(separator: "; ")
        let readiness = readinessTrendSummaries.isEmpty
            ? "No readiness snapshots"
            : readinessTrendSummaries.joined(separator: "; ")
        return """
        Week sessions (\(sessions.count)): \(names.isEmpty ? "none" : names)
        Readiness notes: \(readiness)
        Workouts this week metric: \(dataVM.workoutsThisWeek)
        """
    }
}
