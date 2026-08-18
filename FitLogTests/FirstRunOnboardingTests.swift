//
//  FirstRunOnboardingTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct FirstRunOnboardingTests {

    @Test @MainActor func resetFirstRunExperience_clearsOnboardingAndSpotlight() {
        let suite = UserDefaults(suiteName: "fitlog.tests.first-run.\(UUID().uuidString)")!
        let prefs = UserPreferences(defaults: suite)
        prefs.markOnboardingComplete()
        prefs.markSpotlightTourCompleted()
        prefs.coachMarkHomeDismissed = true
        prefs.hasLoggedFirstWorkout = true

        prefs.resetFirstRunExperience()

        #expect(!prefs.hasCompletedOnboarding)
        #expect(!prefs.spotlightTourCompleted)
        #expect(!prefs.coachMarkHomeDismissed)
        #expect(!prefs.hasLoggedFirstWorkout)
    }

    @Test @MainActor func applyUITestDefaults_skipsOnboardingAndSpotlight() {
        let suite = UserDefaults(suiteName: "fitlog.tests.uitest.\(UUID().uuidString)")!
        let prefs = UserPreferences(defaults: suite)
        prefs.applyUITestDefaults()
        #expect(prefs.hasCompletedOnboarding)
        #expect(prefs.spotlightTourCompleted)
    }

    @Test @MainActor func spotlightTour_startsQueuedExploreAndCompletes() {
        let tour = SpotlightTourController()
        tour.queue(.explore)
        #expect(tour.hasQueuedTour)
        tour.startIfQueued(
            alreadyCompleted: false,
            hasProgram: false,
            hasWorkouts: false,
            workoutInProgress: false
        )
        #expect(tour.isActive)
        #expect(tour.currentStep?.target == .firstRunHero)
        #expect(!tour.isLastStep)
        tour.advance()
        tour.advance()
        #expect(tour.isLastStep)
        tour.advance()
        #expect(!tour.isActive)
        #expect(!tour.hasQueuedTour)
    }

    @Test @MainActor func spotlightTour_programQueueFallsBackToExploreWithoutContent() {
        let tour = SpotlightTourController()
        tour.queue(.afterProgram)
        tour.startIfQueued(
            alreadyCompleted: false,
            hasProgram: false,
            hasWorkouts: false,
            workoutInProgress: false
        )
        #expect(tour.currentStep?.target == .firstRunHero)
    }

    @Test @MainActor func spotlightTour_doesNotStartWhenAlreadyCompleted() {
        let tour = SpotlightTourController()
        tour.queue(.explore)
        tour.startIfQueued(
            alreadyCompleted: true,
            hasProgram: false,
            hasWorkouts: false,
            workoutInProgress: false
        )
        #expect(!tour.isActive)
    }

    @Test @MainActor func spotlightTour_keepsQueueWhenWorkoutInProgressThenStartsLater() {
        let tour = SpotlightTourController()
        tour.queue(.afterWorkout)
        tour.startIfQueued(
            alreadyCompleted: false,
            hasProgram: false,
            hasWorkouts: true,
            workoutInProgress: true
        )
        #expect(!tour.isActive)
        #expect(tour.hasQueuedTour)

        tour.startIfQueued(
            alreadyCompleted: false,
            hasProgram: false,
            hasWorkouts: true,
            workoutInProgress: false
        )
        #expect(tour.isActive)
        #expect(!tour.hasQueuedTour)
        #expect(tour.currentStep?.target == .workoutsList)
    }

    @Test func catalog_hasThreeStepsPerKind() {
        #expect(SpotlightTourCatalog.steps(for: .explore).count == 3)
        #expect(SpotlightTourCatalog.steps(for: .afterProgram).count == 3)
        #expect(SpotlightTourCatalog.steps(for: .afterWorkout).count == 3)
    }
}
