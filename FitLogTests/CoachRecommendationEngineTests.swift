//
//  CoachRecommendationEngineTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class CoachRecommendationEngineTests: XCTestCase {

    func testMuscleGainFourDaysRecommendsUpperLower() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.upperLower.rawValue)
        XCTAssertEqual(blueprint.sessionsPerWeek, 4)
        XCTAssertNotEqual(blueprint.cardioConfiguration.preference, .none)
    }

    func testFatLossEnablesCardioWithAppropriateGoal() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.fatLoss.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertEqual(blueprint.cardioConfiguration.goal, .fatLoss)
        XCTAssertTrue(blueprint.cardioConfiguration.preference.includesPostWorkoutFinishers
            || blueprint.cardioConfiguration.preference.includesDedicatedCardioDays)
    }

    func testBeginnerUsesConservativeSinglePhasePlan() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.general.rawValue,
            experienceLevel: CoachExperiencePick.beginner.rawValue,
            sessionsPerWeek: 3
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.fullBody.rawValue)
        XCTAssertFalse(blueprint.isPeriodized)
        XCTAssertEqual(blueprint.totalWeeks, 8)
    }

    func testAdvancedFiveDaysAllowsHigherFrequencySplit() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.advanced.rawValue,
            sessionsPerWeek: 5
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.pushPullLegs.rawValue)
        XCTAssertGreaterThanOrEqual(blueprint.totalWeeks, 8)
    }

    func testBlueprintMapsToGenerationRequest() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.strength.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4,
            equipment: CoachEquipmentPick.fullGym.rawValue
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        let request = blueprint.toGenerationRequest()

        XCTAssertEqual(request.splitInput.primaryGoal, intake.primaryGoal)
        XCTAssertEqual(request.splitInput.sessionsPerWeek, 4)
        XCTAssertEqual(request.splitInput.splitPreference, blueprint.splitPreference)
        XCTAssertEqual(request.programName, blueprint.programName)
        XCTAssertFalse(request.blockSpecs.isEmpty)
    }

    func testUserOverrideWinsOverRecommendation() {
        var intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        var blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        let change = CoachRecommendationEngine.applyRecommendationChange(
            to: &blueprint,
            topic: .split,
            newValue: CoachSplitPick.pushPullLegs.rawValue
        )

        XCTAssertNotNil(change)
        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.pushPullLegs.rawValue)
        XCTAssertEqual(blueprint.recommendation(for: .split)?.finalValue, CoachSplitPick.pushPullLegs.rawValue)
    }

    func testConfirmationDiffReflectsBeforeAndAfter() {
        var intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        var blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        let originalLength = blueprint.totalWeeks

        let change = CoachRecommendationEngine.applyRecommendationChange(
            to: &blueprint,
            topic: .programLength,
            newValue: CoachProgramLengthPick.twelve.label
        )

        XCTAssertNotNil(change)
        XCTAssertEqual(blueprint.totalWeeks, 12)
        XCTAssertNotEqual(blueprint.totalWeeks, originalLength)
        XCTAssertTrue(change?.diffDescription.contains("Program length") ?? false)
    }

    func testCardioDedicatedDaysAreInferredNotRequiredFromUser() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.fatLoss.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertNotNil(blueprint.recommendation(for: .cardio))
        if blueprint.cardioConfiguration.preference.includesDedicatedCardioDays {
            XCTAssertGreaterThanOrEqual(blueprint.cardioConfiguration.dedicatedDayCount, 1)
        }
    }

    func testCardioConfigurationMapsIntoRequest() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.fatLoss.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        let request = blueprint.toGenerationRequest()

        XCTAssertEqual(
            CardioProgramPreference.fromStored(request.splitInput.cardioPreference),
            blueprint.cardioConfiguration.preference
        )
        XCTAssertEqual(
            CardioProgramGoal.fromStored(request.splitInput.cardioGoal),
            blueprint.cardioConfiguration.goal
        )
    }

    func testNoAIEngineProducesCompleteBlueprint() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.general.rawValue,
            experienceLevel: CoachExperiencePick.beginner.rawValue,
            sessionsPerWeek: 3
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertFalse(blueprint.recommendations.isEmpty)
        XCTAssertFalse(blueprint.programName.isEmpty)
        XCTAssertFalse(blueprint.blockSpecs.isEmpty)
        let request = blueprint.toGenerationRequest()
        XCTAssertGreaterThan(request.splitInput.sessionsPerWeek, 0)
    }
}
