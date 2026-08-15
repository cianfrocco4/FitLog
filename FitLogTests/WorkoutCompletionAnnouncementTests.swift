//
//  WorkoutCompletionAnnouncementTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct WorkoutCompletionAnnouncementTests {

    @Test func message_includesCoreStats() {
        let summary = WorkoutCompletionSummary(
            id: UUID(),
            workoutName: "Push Day",
            durationSeconds: 2700,
            totalSets: 18,
            totalVolumePounds: 12_500,
            exercisesWithSets: 5,
            totalResolvedExercises: 6,
            personalRecordCount: 0,
            exerciseBreakdown: [],
            personalRecordHighlights: [],
            totalCardioDurationSeconds: 0,
            totalCardioDistanceMeters: 0,
            cardioSegmentCount: 0
        )
        let message = WorkoutCompletionAnnouncement.message(summary: summary, displayUnit: .pounds)
        #expect(message.contains("Workout complete"))
        #expect(message.contains("Push Day"))
        #expect(message.contains("45 minutes"))
        #expect(!message.contains("45:00"))
        #expect(message.contains("18 working sets"))
        #expect(message.contains("12500 lb"))
        #expect(!message.contains("personal record"))
    }

    @Test func message_includesPersonalRecordsWhenPresent() {
        let summary = WorkoutCompletionSummary(
            id: UUID(),
            workoutName: "Legs",
            durationSeconds: 60,
            totalSets: 1,
            totalVolumePounds: 225,
            exercisesWithSets: 1,
            totalResolvedExercises: 1,
            personalRecordCount: 1,
            exerciseBreakdown: [],
            personalRecordHighlights: ["Squat e1RM"],
            totalCardioDurationSeconds: 0,
            totalCardioDistanceMeters: 0,
            cardioSegmentCount: 0
        )
        let message = WorkoutCompletionAnnouncement.message(summary: summary, displayUnit: .pounds)
        #expect(message.contains("1 working set"))
        #expect(message.contains("1 personal record set"))
    }

    @Test func message_handlesEmptyWorkoutName() {
        let summary = WorkoutCompletionSummary(
            id: UUID(),
            workoutName: "  ",
            durationSeconds: 0,
            totalSets: 0,
            totalVolumePounds: 0,
            exercisesWithSets: 0,
            totalResolvedExercises: 0,
            personalRecordCount: 0,
            exerciseBreakdown: [],
            personalRecordHighlights: [],
            totalCardioDurationSeconds: 0,
            totalCardioDistanceMeters: 0,
            cardioSegmentCount: 0
        )
        let message = WorkoutCompletionAnnouncement.message(summary: summary, displayUnit: .kilograms)
        #expect(message.hasPrefix("Workout complete. Duration"))
        #expect(message.contains("0 seconds"))
        #expect(message.contains("0 working sets"))
        #expect(message.contains("kg"))
    }
}
