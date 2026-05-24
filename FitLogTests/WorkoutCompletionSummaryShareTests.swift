//
//  WorkoutCompletionSummaryShareTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class WorkoutCompletionSummaryShareTests: XCTestCase {

    func testShareLinesIncludesCardioTotalsWhenBreakdownEmpty() {
        let summary = WorkoutCompletionSummary(
            id: UUID(),
            workoutName: "Morning Run",
            durationSeconds: 1800,
            totalSets: 0,
            totalVolumePounds: 0,
            exercisesWithSets: 0,
            totalResolvedExercises: 1,
            personalRecordCount: 0,
            exerciseBreakdown: [],
            personalRecordHighlights: [],
            totalCardioDurationSeconds: 1800,
            totalCardioDistanceMeters: 5000,
            cardioSegmentCount: 2
        )
        let text = summary.shareLines(displayUnit: .pounds)
        XCTAssertTrue(text.contains("Cardio:"))
        XCTAssertTrue(text.contains("30:00") || text.contains("0:30"))
        XCTAssertTrue(text.contains("km") || text.contains("m"))
    }

    func testShareLinesUsesCardioSummaryForCardioExerciseRow() {
        let summary = WorkoutCompletionSummary(
            id: UUID(),
            workoutName: "Intervals",
            durationSeconds: 2400,
            totalSets: 0,
            totalVolumePounds: 0,
            exercisesWithSets: 1,
            totalResolvedExercises: 1,
            personalRecordCount: 0,
            exerciseBreakdown: [
                WorkoutCompletionExerciseLine(
                    exerciseName: "Treadmill",
                    workingSetCount: 6,
                    volumePounds: 0,
                    newPRSetCount: 0,
                    cardioSummary: "24:00 · 8.5 km"
                )
            ],
            personalRecordHighlights: [],
            totalCardioDurationSeconds: 1440,
            totalCardioDistanceMeters: 8500,
            cardioSegmentCount: 6
        )
        let text = summary.shareLines(displayUnit: .pounds)
        XCTAssertTrue(text.contains("24:00 · 8.5 km"))
        XCTAssertFalse(text.contains("0 sets"))
    }
}
