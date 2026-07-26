//
//  HistoryDayRangeTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct HistoryDayRangeTests {

    @Test func freeUserEffectiveRange_clampsPremiumSelectionTo14Days() {
        #expect(HistoryDayRange.effectiveRange(selected: .d90, isPremium: false) == .d14)
        #expect(HistoryDayRange.effectiveRange(selected: .d30, isPremium: false) == .d14)
        #expect(HistoryDayRange.effectiveRange(selected: .ytd, isPremium: false) == .d14)
    }

    @Test func freeUserEffectiveRange_keepsFreeSelections() {
        #expect(HistoryDayRange.effectiveRange(selected: .d7, isPremium: false) == .d7)
        #expect(HistoryDayRange.effectiveRange(selected: .d14, isPremium: false) == .d14)
    }

    @Test func premiumUserEffectiveRange_preservesSelection() {
        #expect(HistoryDayRange.effectiveRange(selected: .d90, isPremium: true) == .d90)
        #expect(HistoryDayRange.effectiveRange(selected: .ytd, isPremium: true) == .ytd)
    }
}
