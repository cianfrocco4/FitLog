//
//  WorkoutCompletionNavigationTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct WorkoutCompletionNavigationTests {

    @Test func summaryIdMatchesSessionIdForHistoryDeepLink() {
        let sessionID = UUID()
        let summary = WorkoutCompletionSummary(
            id: sessionID,
            workoutName: "Push Day",
            durationSeconds: 3600,
            totalSets: 12,
            totalVolumePounds: 10000,
            exercisesWithSets: 4,
            totalResolvedExercises: 5,
            personalRecordCount: 1,
            exerciseBreakdown: [],
            personalRecordHighlights: [],
            totalCardioDurationSeconds: 0,
            totalCardioDistanceMeters: 0,
            cardioSegmentCount: 0
        )
        #expect(summary.id == sessionID)
    }

    @Test func doneDismissMayOfferPostWorkoutPaywall() {
        #expect(WorkoutCompletionNavigation.shouldOfferPostWorkoutPaywall(after: .done))
    }

    @Test func viewInHistoryDismissSkipsPostWorkoutPaywall() {
        #expect(!WorkoutCompletionNavigation.shouldOfferPostWorkoutPaywall(after: .viewInHistory))
    }

    @Test func viewInHistoryHintNamesWorkout() {
        let hint = WorkoutCompletionNavigation.viewInHistoryAccessibilityHint(workoutName: "Pull Day")
        #expect(hint == "Opens Pull Day in History")
    }

    @Test func startAgainDismissSkipsPostWorkoutPaywall() {
        #expect(!WorkoutCompletionNavigation.shouldOfferPostWorkoutPaywall(after: .startAgain))
    }

    @Test func startAgainHintNamesWorkout() {
        let hint = WorkoutCompletionNavigation.startAgainAccessibilityHint(workoutName: "Zone 2")
        #expect(hint == "Starts a new Zone 2 session. The finished entry stays in History.")
    }
}
