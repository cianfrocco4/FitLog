//
//  DailyAdjustHeuristicsTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct DailyAdjustHeuristicsTests {
    @Test func highReadinessKeepsPlan() {
        let proposal = DailyAdjustHeuristics.proposal(for: DailyAdjustContextPack(
            dayKey: "2026-07-26",
            readinessScore: 80,
            readinessSummary: "Good",
            plannedWorkoutName: "Push",
            plannedWorkoutDetail: "Bench",
            recentLoadSummary: "normal",
            userNote: "",
            hasDynamicProgram: true
        ))
        #expect(proposal.changes.contains(where: { $0.kind == .keepAsPlanned }))
    }
}
