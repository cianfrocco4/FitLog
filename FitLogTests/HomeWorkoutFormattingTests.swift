//
//  HomeWorkoutFormattingTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HomeWorkoutFormattingTests {
    @Test func compactWeightLabel_formatsPoundsAndKilograms() {
        #expect(HomeWorkoutFormatting.compactWeightLabel(pounds: 185, unit: .pounds) == "185 lb")
        #expect(HomeWorkoutFormatting.compactWeightLabel(pounds: 0, unit: .pounds) == nil)
        #expect(HomeWorkoutFormatting.compactWeightLabel(pounds: nil, unit: .pounds) == nil)
        #expect(HomeWorkoutFormatting.compactWeightLabel(pounds: 220.46226218, unit: .kilograms) == "100 kg")
    }

    @Test func lastDoneWithWeight_appendsWorkingLoad() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(
            HomeWorkoutFormatting.lastDoneWithWeightLabel(
                date: yesterday,
                weightPounds: 185,
                unit: .pounds,
                reference: today,
                calendar: cal
            ) == "Last done yesterday · 185 lb"
        )
        #expect(
            HomeWorkoutFormatting.lastDoneWithWeightLabel(
                date: yesterday,
                weightPounds: nil,
                unit: .pounds,
                reference: today,
                calendar: cal
            ) == "Last done yesterday"
        )
    }
}
