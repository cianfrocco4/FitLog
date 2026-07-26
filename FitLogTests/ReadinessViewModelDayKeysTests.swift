//
//  ReadinessViewModelDayKeysTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct ReadinessViewModelDayKeysTests {

    @Test func dayKeys_returnsRequestedCount() {
        let keys = ReadinessViewModel.dayKeys(endingAt: "2026-06-28", count: 7)
        #expect(keys.count == 7)
    }

    @Test func dayKeys_endsAtProvidedDay() {
        let keys = ReadinessViewModel.dayKeys(endingAt: "2026-06-28", count: 3)
        #expect(keys.last == "2026-06-28")
    }

    @Test func dayKeys_isChronological() {
        let keys = ReadinessViewModel.dayKeys(endingAt: "2026-06-28", count: 3)
        #expect(keys == ["2026-06-26", "2026-06-27", "2026-06-28"])
    }

    @Test func dayKeys_emptyWhenCountZero() {
        #expect(ReadinessViewModel.dayKeys(endingAt: "2026-06-28", count: 0).isEmpty)
    }

    @Test func dayKeys_emptyForInvalidDayKey() {
        #expect(ReadinessViewModel.dayKeys(endingAt: "not-a-date", count: 7).isEmpty)
    }
}
