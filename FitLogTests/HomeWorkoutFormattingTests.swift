//
//  HomeWorkoutFormattingTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HomeWorkoutFormattingTests {
    @Test func compactDurationLabel_formatsMinutes() {
        #expect(HomeWorkoutFormatting.compactDurationLabel(seconds: 45 * 60) == "45m")
        #expect(HomeWorkoutFormatting.compactDurationLabel(seconds: 65 * 60) == "1h 5m")
        #expect(HomeWorkoutFormatting.compactDurationLabel(seconds: 10) == nil)
        #expect(HomeWorkoutFormatting.compactDurationLabel(seconds: nil) == nil)
    }

    @Test func lastDoneWithDuration_appendsCardioMinutes() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        #expect(
            HomeWorkoutFormatting.lastDoneWithDurationLabel(
                date: yesterday,
                durationSeconds: 45 * 60,
                reference: today,
                calendar: cal
            ) == "Last done yesterday · 45m"
        )
        #expect(
            HomeWorkoutFormatting.lastDoneWithDurationLabel(
                date: yesterday,
                durationSeconds: nil,
                reference: today,
                calendar: cal
            ) == "Last done yesterday"
        )
    }

    @Test func libraryDetailLine_prefersLastCardioDurationOverEstimate() {
        #expect(
            HomeWorkoutFormatting.libraryDetailLine(
                kind: .cardio,
                exerciseCount: 1,
                lastLoggedSeconds: 45 * 60,
                emptySubtitle: "Empty workout"
            ) == "1 exercise · last 45m"
        )
        #expect(
            HomeWorkoutFormatting.libraryDetailLine(
                kind: .strength,
                exerciseCount: 4,
                lastLoggedSeconds: nil,
                emptySubtitle: "Empty workout"
            ) == "4 exercises · ~32 min"
        )
        #expect(
            HomeWorkoutFormatting.libraryDetailLine(
                kind: .cardio,
                exerciseCount: 0,
                lastLoggedSeconds: 45 * 60,
                emptySubtitle: "Empty workout"
            ) == "Last 45m"
        )
    }
}
