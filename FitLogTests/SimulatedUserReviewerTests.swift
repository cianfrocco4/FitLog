//
//  SimulatedUserReviewerTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite @MainActor
struct SimulatedUserReviewerTests {

    /// Monday 17 Aug 2026.
    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!
    /// Tuesday 18 Aug 2026.
    private let tuesday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 12))!

    @Test func returningFree_dislikesFourteenDayHistoryCap() throws {
        let dm = try makeSeeded(.returningFree, now: monday)
        let review = FitLogSimulatedUserReviewer.makeReview(
            .returningFree,
            dataVM: dm,
            tickOutcome: .restDay,
            now: monday,
            isAIConfigured: false
        )
        #expect(review.dislikes.contains { $0.id == "dislike.history.14_day_cap" })
        #expect(review.improvements.contains { $0.id == "improve.history.free_peek" })
        #expect(review.dislikes.contains { $0.id == "dislike.coach.premium_gate" })
        #expect(review.likes.contains { $0.id == "like.home.start_recent" })
        #expect(review.oldestSessionDaysAgo ?? 0 >= 30)
        #expect(review.markdown().contains("Dislikes"))
    }

    @Test func premiumLifter_likesUnlimitedHistory_andFlagsUnconfiguredCoach() throws {
        let dm = try makeSeeded(.premiumLifter, now: monday)
        let review = FitLogSimulatedUserReviewer.makeReview(
            .premiumLifter,
            dataVM: dm,
            tickOutcome: .alreadyLoggedToday,
            now: monday,
            isAIConfigured: false
        )
        #expect(review.isPremium)
        #expect(review.likes.contains { $0.id == "like.history.unlimited" })
        #expect(review.dislikes.contains { $0.id == "dislike.coach.ai_unconfigured" })
        #expect(!review.dislikes.contains { $0.id == "dislike.history.14_day_cap" })
        #expect(review.likes.contains { $0.id == "like.idempotent.no_duplicate" })
        #expect(review.improvements.contains { $0.id == "improve.home.already_trained" })
    }

    @Test func premiumLifter_skipsAIComplaintWhenConfigured() throws {
        let dm = try makeSeeded(.premiumLifter, now: monday)
        let review = FitLogSimulatedUserReviewer.makeReview(
            .premiumLifter,
            dataVM: dm,
            tickOutcome: .logged,
            now: monday,
            isAIConfigured: true
        )
        #expect(!review.dislikes.contains { $0.id == "dislike.coach.ai_unconfigured" })
        #expect(review.likes.contains { $0.id == "like.history.logged" })
    }

    @Test func newFree_afterFirstLog_likesTemplates() throws {
        let dm = try makeEmptyManager()
        _ = FitLogSimulatedUserLivingDay.runTick(
            .newFree,
            into: dm,
            now: tuesday,
            writeTickLog: false
        )
        let review = FitLogSimulatedUserReviewer.makeReview(
            .newFree,
            dataVM: dm,
            tickOutcome: .logged,
            now: tuesday,
            isAIConfigured: false
        )
        #expect(review.likes.contains { $0.id == "like.library.templates" })
        #expect(review.dislikes.contains { $0.id == "dislike.home.few_templates" })
        #expect(review.sessionCount == 1)
        #expect(review.bugs.isEmpty)
    }

    @Test func emptyLibraryOnTrainingDay_isABug() throws {
        let dm = try makeEmptyManager()
        let review = FitLogSimulatedUserReviewer.makeReview(
            .returningFree,
            dataVM: dm,
            tickOutcome: .skippedEmptyLibrary,
            now: monday,
            isAIConfigured: false
        )
        #expect(review.bugs.contains { $0.id == "bug.library.empty_on_training_day" })
    }

    @Test func unloggableWorkout_isNotEmptyLibraryBug() throws {
        let dm = try makeEmptyManager()
        FitLogSimulatedUserSeeder.seedStrengthLibrary(
            into: dm,
            templates: Array(WorkoutQuickStartTemplate.all.prefix(1))
        )
        let review = FitLogSimulatedUserReviewer.makeReview(
            .returningFree,
            dataVM: dm,
            tickOutcome: .skippedUnloggableWorkout,
            now: monday,
            isAIConfigured: false
        )
        #expect(!review.bugs.contains { $0.id == "bug.library.empty_on_training_day" })
        #expect(review.bugs.contains { $0.id == "bug.library.unloggable_workout" })
        #expect(review.workflow.contains("nothing to log"))
    }

    @Test func skippedEmptyLibrary_withNonEmptyLibrary_isNotEmptyLibraryBug() throws {
        let dm = try makeEmptyManager()
        FitLogSimulatedUserSeeder.seedStrengthLibrary(
            into: dm,
            templates: Array(WorkoutQuickStartTemplate.all.prefix(1))
        )
        let review = FitLogSimulatedUserReviewer.makeReview(
            .returningFree,
            dataVM: dm,
            tickOutcome: .skippedEmptyLibrary,
            now: monday,
            isAIConfigured: false
        )
        #expect(!review.bugs.contains { $0.id == "bug.library.empty_on_training_day" })
    }

    @Test func planFollower_withoutTodayAssignment_isABug() throws {
        let dm = try makeEmptyManager()
        FitLogSimulatedUserSeeder.seedStrengthLibrary(
            into: dm,
            templates: Array(WorkoutQuickStartTemplate.all.prefix(1))
        )
        let review = FitLogSimulatedUserReviewer.makeReview(
            .planFollower,
            dataVM: dm,
            tickOutcome: .logged,
            now: monday,
            isAIConfigured: false
        )
        #expect(review.bugs.contains { $0.id == "bug.plan.missing_today" })
        #expect(!review.likes.contains { $0.id == "like.plan.today" })
    }

    @Test func planFollower_withTodayAssigned_likesPlan() throws {
        let dm = try makeSeeded(.planFollower, now: monday)
        let review = FitLogSimulatedUserReviewer.makeReview(
            .planFollower,
            dataVM: dm,
            tickOutcome: .restDay,
            now: monday,
            isAIConfigured: false
        )
        #expect(review.likes.contains { $0.id == "like.plan.today" })
        #expect(!review.bugs.contains { $0.id == "bug.plan.missing_today" })
    }

    @Test func cardioHobbyist_likesLibrary_andFlagsMissingCardioHistory() throws {
        let dm = try makeEmptyManager()
        FitLogSimulatedUserSeeder.seedCardioLibrary(into: dm)
        FitLogSimulatedUserSeeder.seedStrengthLibrary(
            into: dm,
            templates: Array(WorkoutQuickStartTemplate.all.prefix(1))
        )
        _ = FitLogSimulatedUserSeeder.logCompletedWorkout(
            from: dm.userWorkouts.first { $0.workoutKind != .cardio } ?? dm.userWorkouts[0],
            endedAt: monday,
            into: dm,
            cardio: false
        )
        let review = FitLogSimulatedUserReviewer.makeReview(
            .cardioHobbyist,
            dataVM: dm,
            tickOutcome: .logged,
            now: tuesday,
            isAIConfigured: false
        )
        #expect(review.likes.contains { $0.id == "like.cardio.library" })
        #expect(review.bugs.contains { $0.id == "bug.cardio.no_cardio_sessions" })
        #expect(review.dislikes.contains { $0.id == "dislike.cardio.no_trends" })
    }

    @Test func restDay_notesQuietWorkflow() throws {
        let dm = try makeSeeded(.returningFree, now: monday)
        let review = FitLogSimulatedUserReviewer.makeReview(
            .returningFree,
            dataVM: dm,
            tickOutcome: .restDay,
            now: tuesday,
            isAIConfigured: false
        )
        #expect(review.likes.contains { $0.id == "like.rest.no_nag" })
        #expect(review.isTrainingDay == false)
        #expect(review.workflow.contains("Rest day"))
    }

    private func makeEmptyManager() throws -> DataManager {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let dm = DataManager(modelContainer: container)
        dm.eraseAllAppData(createSafetyBackup: false)
        return dm
    }

    private func makeSeeded(_ persona: FitLogSimulatedUserPersona, now: Date) throws -> DataManager {
        let dm = try makeEmptyManager()
        FitLogSimulatedUserSeeder.seed(persona, into: dm, now: now)
        return dm
    }
}
