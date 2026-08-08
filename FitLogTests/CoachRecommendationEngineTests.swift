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
        XCTAssertEqual(blueprint.totalWeeks, 12)
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
        XCTAssertEqual(blueprint.totalWeeks, 8)
        XCTAssertFalse(blueprint.isPeriodized)
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

    func testAdvancedFiveDaysMuscleAllowsBroSplit() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.advanced.rawValue,
            sessionsPerWeek: 5
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)

        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.broSplit.rawValue)
        XCTAssertEqual(blueprint.totalWeeks, 12)
    }

    func testGoalsProduceDistinctBlueprints() {
        let base = CoachIntakeSnapshot(
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4,
            equipment: CoachEquipmentPick.fullGym.rawValue,
            sessionDurationMinutes: 60
        )

        var muscle = base
        muscle.primaryGoal = CoachGoalPick.buildMuscle.rawValue
        var strength = base
        strength.primaryGoal = CoachGoalPick.strength.rawValue
        var fat = base
        fat.primaryGoal = CoachGoalPick.fatLoss.rawValue
        var athletic = base
        athletic.primaryGoal = CoachGoalPick.performance.rawValue

        let muscleBP = CoachRecommendationEngine.buildBlueprint(from: muscle)
        let strengthBP = CoachRecommendationEngine.buildBlueprint(from: strength)
        let fatBP = CoachRecommendationEngine.buildBlueprint(from: fat)
        let athleticBP = CoachRecommendationEngine.buildBlueprint(from: athletic)

        XCTAssertNotEqual(muscleBP.intensityStyle, strengthBP.intensityStyle)
        XCTAssertNotEqual(muscleBP.blockSpecs.first?.title, strengthBP.blockSpecs.first?.title)
        XCTAssertEqual(muscleBP.totalWeeks, 12)
        XCTAssertEqual(strengthBP.totalWeeks, 12)
        XCTAssertEqual(fatBP.totalWeeks, 8)
        XCTAssertEqual(athleticBP.totalWeeks, 10)
        XCTAssertEqual(fatBP.cardioConfiguration.goal, .fatLoss)
        XCTAssertEqual(athleticBP.cardioConfiguration.goal, .enduranceBuilding)

        let muscleDirective = muscleBP.toGenerationRequest().splitInput.goalProgrammingDirective
        let strengthDirective = strengthBP.toGenerationRequest().splitInput.goalProgrammingDirective
        XCTAssertFalse(muscleDirective.isEmpty)
        XCTAssertFalse(strengthDirective.isEmpty)
        XCTAssertNotEqual(muscleDirective, strengthDirective)
        XCTAssertTrue(muscleDirective.localizedCaseInsensitiveContains("hypertrophy"))
        XCTAssertTrue(strengthDirective.localizedCaseInsensitiveContains("stronger")
            || strengthDirective.localizedCaseInsensitiveContains("strength"))
    }

    func testBlueprintMapsToGenerationRequest() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.strength.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4,
            equipment: CoachEquipmentPick.fullGym.rawValue,
            sessionDurationMinutes: 45,
            priorityMusclesOrLiftsNotes: "Squat and deadlift"
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        let request = blueprint.toGenerationRequest()

        XCTAssertEqual(request.splitInput.primaryGoal, intake.primaryGoal)
        XCTAssertEqual(request.splitInput.sessionsPerWeek, 4)
        XCTAssertEqual(request.splitInput.splitPreference, blueprint.splitPreference)
        XCTAssertEqual(request.programName, blueprint.programName)
        XCTAssertEqual(request.splitInput.sessionDurationMinutes, 45)
        XCTAssertEqual(request.splitInput.priorityMusclesOrLiftsNotes, "Squat and deadlift")
        XCTAssertFalse(request.splitInput.goalProgrammingDirective.isEmpty)
        XCTAssertFalse(request.blockSpecs.isEmpty)
    }

    func testUserOverrideWinsOverRecommendation() {
        let intake = CoachIntakeSnapshot(
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
        XCTAssertTrue(blueprint.recommendation(for: .split)?.userChangedFromRecommendation ?? false)
    }

    func testRederiveUpdatesUnlockedButKeepsLocked() {
        var intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 5
        )
        var blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.broSplit.rawValue)

        _ = CoachRecommendationEngine.applyRecommendationChange(
            to: &blueprint,
            topic: .programName,
            newValue: "Custom Name"
        )

        intake.sessionsPerWeek = 4
        let updates = CoachRecommendationEngine.rederive(blueprint: &blueprint, intake: intake)

        XCTAssertEqual(blueprint.programName, "Custom Name")
        XCTAssertTrue(blueprint.recommendation(for: .programName)?.userChangedFromRecommendation ?? false)
        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.upperLower.rawValue)
        XCTAssertTrue(updates.contains(where: { $0.topic == .split }))
    }

    func testApplyScheduleChangeClampsSessions() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.general.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4,
            preferredWeekdays: [1, 2, 3, 4]
        )
        var blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        CoachRecommendationEngine.applyScheduleChange(to: &blueprint, sessions: 4, weekdays: [1, 2])
        XCTAssertEqual(blueprint.sessionsPerWeek, 2)
        XCTAssertEqual(blueprint.preferredWeekdays, [1, 2])
    }

    func testConfirmationDiffReflectsBeforeAndAfter() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.buildMuscle.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4
        )
        var blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        // Muscle defaults to 12 weeks — pick a different length so the change is non-nil.
        let target = CoachProgramLengthPick.eight
        XCTAssertNotEqual(blueprint.totalWeeks, target.rawValue)

        let change = CoachRecommendationEngine.applyRecommendationChange(
            to: &blueprint,
            topic: .programLength,
            newValue: target.label
        )

        XCTAssertNotNil(change)
        XCTAssertEqual(blueprint.totalWeeks, target.rawValue)
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
        XCTAssertFalse(request.splitInput.goalProgrammingDirective.isEmpty)
    }

    func testSavedSplitUsedOnlyWhenCompatible() {
        let intake = CoachIntakeSnapshot(
            primaryGoal: CoachGoalPick.strength.rawValue,
            experienceLevel: CoachExperiencePick.intermediate.rawValue,
            sessionsPerWeek: 4,
            savedSplitPreference: CoachSplitPick.upperLower.rawValue
        )
        let blueprint = CoachRecommendationEngine.buildBlueprint(from: intake)
        XCTAssertTrue(blueprint.usedSavedSplitPreference)
        XCTAssertEqual(blueprint.splitPreference, CoachSplitPick.upperLower.rawValue)
    }
}
