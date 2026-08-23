//
//  HistoryFreePeekTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite @MainActor
struct HistoryFreePeekTests {

    /// Monday 17 Aug 2026.
    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!

    @Test func copy_namesRangeAndKeepsChartsLocked() {
        #expect(HistoryFreePeek.olderSectionTitle(range: .d14) == "Older than last 14 days")
        #expect(HistoryFreePeek.olderSectionTitle(range: .d7) == "Older than last 7 days")
        #expect(HistoryFreePeek.olderSectionFooter(range: .d14).contains("last 14 days"))
        #expect(HistoryFreePeek.emptyInRangeMessage(range: .d14).contains("Older sessions"))
        #expect(HistoryFreePeek.overviewBannerTitle(count: 1) == "1 older session")
        #expect(HistoryFreePeek.overviewBannerTitle(count: 3) == "3 older sessions")
        #expect(HistoryFreePeek.overviewBannerDetail(count: 2, range: .d14).contains("charts stay"))
        #expect(HistoryFreePeek.overviewBannerAccessibilityHint().contains("Sessions"))
    }

    @Test func aggregator_splitsInRangeFromOlderWithoutChangingCutoff() throws {
        let dm = try makeSeededReturningFree()
        let cutoff = HistoryDayRange.d14.cutoff(from: monday)
        let inRange = HistoryAggregator.sessionsInDateRange(
            from: dm.completedSessions,
            cutoff: cutoff
        )
        let older = HistoryAggregator.sessionsOutsideDateRange(
            from: dm.completedSessions,
            cutoff: cutoff
        )
        let inRangeIDs = Set(inRange.map(\.id))
        #expect(!inRange.isEmpty)
        #expect(!older.isEmpty)
        #expect(inRangeIDs.isDisjoint(with: Set(older.map(\.id))))
        #expect(inRange.count + older.count == dm.completedSessions.count)
        #expect(older.allSatisfy { ($0.endTime ?? $0.startTime) < cutoff })
    }

    @Test func viewModel_listsOlderSessionsWhileKPIsStayInRange() throws {
        let dm = try makeSeededReturningFree()
        let vm = HistoryViewModel()
        vm.dayRange = .d14
        vm.recompute(dataVM: dm, now: monday)
        vm.ensureSessionsData(dataVM: dm)

        #expect(!vm.sessionsInDateRange.isEmpty)
        #expect(!vm.olderSessionsOutsideRange.isEmpty)
        #expect(vm.currentKPIs.sessions == vm.sessionsInDateRange.count)
        #expect(vm.currentKPIs.sessions < dm.completedSessions.count)
        #expect(vm.olderSessionsSectionTitle == "Older than last 14 days")
        #expect(vm.filteredOlderSessionsForSessionsTab.count == vm.olderSessionsOutsideRange.count)
    }

    @Test func viewModel_searchIncludesOlderSessionNames() throws {
        let dm = try makeSeededReturningFree()
        let vm = HistoryViewModel()
        vm.dayRange = .d14
        vm.recompute(dataVM: dm, now: monday)

        guard let olderName = vm.olderSessionsOutsideRange.first?.workout.name,
              !olderName.isEmpty
        else {
            Issue.record("Expected a seeded session older than 14 days")
            return
        }

        vm.sessionsSearch = olderName
        #expect(!vm.filteredOlderSessionsForSessionsTab.isEmpty)
        #expect(vm.filteredOlderSessionsForSessionsTab.contains { $0.workout.name == olderName })
    }

    @Test func effectiveRange_stillClampsPremiumChartsForFreeUsers() {
        #expect(HistoryDayRange.effectiveRange(selected: .d90, isPremium: false) == .d14)
        #expect(HistoryDayRange.effectiveRange(selected: .ytd, isPremium: false) == .d14)
    }

    private func makeSeededReturningFree() throws -> DataManager {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let dm = DataManager(modelContainer: container)
        dm.eraseAllAppData(createSafetyBackup: false)
        FitLogSimulatedUserSeeder.seed(.returningFree, into: dm, now: monday)
        return dm
    }
}
