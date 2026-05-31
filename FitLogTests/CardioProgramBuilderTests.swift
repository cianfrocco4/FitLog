//
//  CardioProgramBuilderTests.swift
//  FitLogTests
//

import SwiftData
import XCTest
@testable import FitLog

@MainActor
final class CardioProgramBuilderTests: XCTestCase {

    func testCardioProgramPreference_fromStored() {
        XCTAssertEqual(
            CardioProgramPreference.fromStored(CardioProgramPreference.postWorkout.rawValue),
            .postWorkout
        )
        XCTAssertEqual(CardioProgramPreference.fromStored(nil), .none)
        XCTAssertEqual(CardioProgramPreference.fromStored("invalid"), .none)
    }

    func testFinisherSlot_hasCardioModalityAndPrescription() {
        let slot = CardioProgramTemplates.finisherSlot(library: [])
        XCTAssertEqual(slot.modality, .cardio)
        XCTAssertNotNil(slot.cardioPrescription)
        XCTAssertEqual(slot.cardioPrescription?.kind, .steadyState)
    }

    func testApplyCardioPreference_postWorkout_appendsFinisher() {
        let day = BlockWeeklyTemplate(
            dayName: "Push",
            focus: "Chest",
            slots: [
                SplitBuilderEditableSlot(
                    label: "Bench",
                    targetMuscleNames: [MuscleGroup.chest.rawValue],
                    sets: 3,
                    reps: "8-12"
                )
            ]
        )
        let result = DynamicProgramMapper.applyCardioPreference(
            to: [day],
            preference: .postWorkout,
            sessionsPerWeek: 3,
            library: []
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].slots.count, 2)
        XCTAssertTrue(result[0].slots.last?.modality == .cardio)
    }

    func testApplyCardioPreference_mixed_appendsFinishersAndDedicatedDays() {
        let templates = (0 ..< 3).map { i in
            BlockWeeklyTemplate(
                dayName: "Day \(i + 1)",
                focus: "",
                slots: [
                    SplitBuilderEditableSlot(
                        label: "Lift",
                        targetMuscleNames: [MuscleGroup.chest.rawValue],
                        sets: 3,
                        reps: "8-12"
                    )
                ]
            )
        }
        let result = DynamicProgramMapper.applyCardioPreference(
            to: templates,
            preference: .mixed,
            sessionsPerWeek: 4,
            library: []
        )
        XCTAssertEqual(result.count, 5)
        XCTAssertTrue(result[0].slots.contains { $0.modality == .cardio })
        XCTAssertTrue(result[0].slots.contains { $0.modality != .cardio })
        XCTAssertTrue(result[templates.count].slots.allSatisfy { $0.modality == .cardio })
    }

    func testApplyCardioPreference_dedicatedDays_respectsConfiguredDayCount() {
        let templates = [
            BlockWeeklyTemplate(
                dayName: "Push",
                focus: "",
                slots: [
                    SplitBuilderEditableSlot(
                        label: "Bench",
                        targetMuscleNames: [MuscleGroup.chest.rawValue],
                        sets: 3,
                        reps: "8-12"
                    )
                ]
            )
        ]
        let config = CardioProgramConfiguration(
            goal: .fatLoss,
            preference: .dedicatedDays,
            dedicatedDayCount: 3
        )
        let result = DynamicProgramMapper.applyCardioPreference(
            to: templates,
            preference: .dedicatedDays,
            sessionsPerWeek: 4,
            library: [],
            configuration: config
        )
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result.filter { $0.slots.allSatisfy { $0.modality == .cardio } }.count, 3)
    }

    func testFinisherSlot_usesConfiguredDurationAndZone() {
        let config = CardioProgramConfiguration(
            goal: .generalHealth,
            preference: .postWorkout,
            finisherDurationMinutes: 15,
            finisherZone: .zone3
        )
        let slot = CardioProgramTemplates.finisherSlot(library: [], configuration: config)
        XCTAssertEqual(slot.cardioPrescription?.targetDurationSec, 15 * 60)
        XCTAssertEqual(slot.cardioPrescription?.targetZone, .zone3)
    }

    func testCardioProgramConfiguration_fromSplitInput() {
        var input = DynamicProgramGenerationRequest.simpleDefault().splitInput
        input.cardioGoal = CardioProgramGoal.fatLoss.rawValue
        input.cardioPreference = CardioProgramPreference.none.rawValue
        input.cardioDedicatedDayCount = 3
        let config = CardioProgramConfiguration.fromSplitInput(input)
        XCTAssertEqual(config.goal, CardioProgramGoal.fatLoss)
        XCTAssertEqual(config.preference, CardioProgramPreference.mixed)
        XCTAssertEqual(config.dedicatedDayCount, 3)
    }

    func testApplyCardioPreference_dedicatedDays_appendsCardioDays() {
        let templates = (0 ..< 4).map { i in
            BlockWeeklyTemplate(
                dayName: "Day \(i + 1)",
                focus: "",
                slots: [
                    SplitBuilderEditableSlot(
                        label: "Lift",
                        targetMuscleNames: [MuscleGroup.chest.rawValue],
                        sets: 3,
                        reps: "8-12"
                    )
                ]
            )
        }
        let result = DynamicProgramMapper.applyCardioPreference(
            to: templates,
            preference: .dedicatedDays,
            sessionsPerWeek: 4,
            library: []
        )
        XCTAssertEqual(result.count, 6)
        XCTAssertTrue(result[0].slots.contains { $0.modality != .cardio })
        XCTAssertEqual(result[0].dayName, "Day 1")
        XCTAssertTrue(result[4].slots.allSatisfy { $0.modality == .cardio })
    }

    func testHybridBlock_preservesStrengthAndInjectsCardio() {
        let proposal = WorkoutSplitProposal(
            rationale: "test",
            sessionsPerWeek: 3,
            preferredWeekdays: [1, 3, 5],
            workouts: [
                WorkoutSplitProposalDay(
                    name: "Push",
                    focus: "Chest",
                    exercises: [],
                    slots: [
                        WorkoutSplitProposalSlotItem(
                            label: "Bench",
                            targetMuscleNames: [MuscleGroup.chest.rawValue],
                            sets: 3,
                            reps: "8-12",
                            suggestedExerciseName: "Bench Press",
                            suggestedExerciseOverrideId: nil
                        )
                    ]
                )
            ]
        )
        let templates = DynamicProgramMapper.weeklyTemplates(
            from: proposal,
            blockFocus: BlockFocus(kind: .hybrid, emphasisLabel: "Strength + cardio"),
            library: [],
            configuration: .none
        )
        XCTAssertGreaterThanOrEqual(templates.count, 2)
        XCTAssertTrue(templates[0].slots.contains { $0.label == "Bench" })
        XCTAssertTrue(templates[0].slots.contains { $0.modality == .cardio })
        XCTAssertTrue(templates.dropFirst().contains { day in
            day.slots.allSatisfy { $0.modality == .cardio } && !day.slots.contains { $0.label == "Bench" }
        })
    }

    func testEnduranceBlock_usesPureCardioRotation() {
        let proposal = WorkoutSplitProposal(
            rationale: "test",
            sessionsPerWeek: 3,
            preferredWeekdays: [],
            workouts: [
                WorkoutSplitProposalDay(
                    name: "Push",
                    focus: nil,
                    exercises: [],
                    slots: [
                        WorkoutSplitProposalSlotItem(
                            label: "Bench",
                            targetMuscleNames: [MuscleGroup.chest.rawValue],
                            sets: 3,
                            reps: "8-12",
                            suggestedExerciseName: nil,
                            suggestedExerciseOverrideId: nil
                        )
                    ]
                )
            ]
        )
        let templates = DynamicProgramMapper.weeklyTemplates(
            from: proposal,
            blockFocus: BlockFocus(kind: .endurance, emphasisLabel: ""),
            library: []
        )
        XCTAssertEqual(templates.count, 3)
        XCTAssertTrue(templates.allSatisfy { $0.slots.allSatisfy { $0.modality == .cardio } })
    }

    func testApplyCardioPreference_dedicatedDays_replacesWhenRotationFull() {
        let templates = (0 ..< 7).map { i in
            BlockWeeklyTemplate(
                dayName: "Day \(i + 1)",
                focus: "",
                slots: [
                    SplitBuilderEditableSlot(
                        label: "Lift",
                        targetMuscleNames: [MuscleGroup.chest.rawValue],
                        sets: 3,
                        reps: "8-12"
                    )
                ]
            )
        }
        let result = DynamicProgramMapper.applyCardioPreference(
            to: templates,
            preference: .dedicatedDays,
            sessionsPerWeek: 6,
            library: []
        )
        XCTAssertEqual(result.count, 7)
        XCTAssertTrue(result[4].slots.allSatisfy { $0.modality == .cardio })
        XCTAssertTrue(result[5].slots.allSatisfy { $0.modality == .cardio })
        XCTAssertTrue(result[6].slots.allSatisfy { $0.modality == .cardio })
        XCTAssertTrue(result[0].slots.contains { $0.modality != .cardio })
    }

    func testDedicatedCardioDay_producesSingleCardioSlot() {
        let day = CardioProgramTemplates.dedicatedCardioDay(library: [], index: 1)
        XCTAssertEqual(day.slots.count, 1)
        XCTAssertEqual(day.slots[0].modality, .cardio)
        XCTAssertEqual(day.slots[0].cardioPrescription?.kind, .intervals)
    }

    func testCardioQuickAddTemplate_resolveExercise_fallback() {
        let run = Exercise(
            id: UUID(),
            name: "Treadmill Run",
            description: "",
            targetedMuscles: [.other],
            isCustom: false,
            configurationOptions: [],
            exerciseRole: .accessory,
            movementPattern: nil,
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(
                activityKind: .run,
                primaryMetric: .time,
                equipment: .treadmill,
                estimatedMETs: 8,
                supportsIntervals: true
            )
        )
        let template = CardioQuickAddTemplate.all[0]
        XCTAssertEqual(template.resolveExercise(in: [run])?.name, "Treadmill Run")
    }

    func testCardioQuickAddTemplate_resolveExercise_emptyLibrary_returnsNil() {
        let template = CardioQuickAddTemplate.all[0]
        XCTAssertNil(template.resolveExercise(in: []))
    }

    func testAISlotPromotion_steadyReps_becomesCardioModality() {
        let slot = SplitBuilderEditableSlot.promotedFromProposal(
            label: "Zone 2",
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 1,
            reps: "steady",
            suggestedExerciseName: nil,
            suggestedExerciseOverrideId: nil,
            library: []
        )
        XCTAssertEqual(slot.modality, .cardio)
        XCTAssertEqual(slot.cardioPrescription?.kind, .steadyState)
        XCTAssertEqual(slot.reps, "steady")
    }

    func testAISlotPromotion_cardioExercise_becomesCardioModality() {
        let runId = UUID()
        let run = Exercise(
            id: runId,
            name: "Treadmill Run",
            description: "",
            targetedMuscles: [.other],
            exerciseRole: .accessory,
            modality: .cardio,
            cardioMetadata: CardioExerciseMetadata(
                activityKind: .run,
                primaryMetric: .time,
                equipment: .treadmill,
                estimatedMETs: 8,
                supportsIntervals: true
            )
        )
        let slot = SplitBuilderEditableSlot.promotedFromProposal(
            label: "Run",
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 3,
            reps: "8-12",
            suggestedExerciseName: "Treadmill Run",
            suggestedExerciseOverrideId: runId,
            library: [run]
        )
        XCTAssertEqual(slot.modality, .cardio)
        XCTAssertNotNil(slot.cardioPrescription)
    }

    func testShouldOfferCardioFinisher_cardioOnlyWorkout_returnsFalse() throws {
        let saved = SplitBuilderPreferencesStore.load()
        defer { SplitBuilderPreferencesStore.save(saved) }
        var state = saved
        state.cardioPreferenceRaw = CardioProgramPreference.postWorkout.rawValue
        SplitBuilderPreferencesStore.save(state)

        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)

        let cardioWE = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Run")),
            recommendedSets: 1,
            recommendedReps: "steady",
            cardioPrescription: CardioPrescription(kind: .steadyState, targetDurationSec: 600)
        )
        let workout = Workout(
            id: UUID(),
            name: "Cardio Day",
            exercises: [cardioWE],
            workoutKind: .cardio
        )
        vm.currentSession = WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date(),
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: cardioWE, loggedSets: [])]
        )

        XCTAssertFalse(vm.shouldOfferCardioFinisherOnFinish())
    }

    func testShouldOfferCardioFinisher_plannedCardioRow_returnsFalse() throws {
        let saved = SplitBuilderPreferencesStore.load()
        defer { SplitBuilderPreferencesStore.save(saved) }
        var state = saved
        state.cardioPreferenceRaw = CardioProgramPreference.postWorkout.rawValue
        SplitBuilderPreferencesStore.save(state)

        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)

        let strengthWE = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Squat")),
            recommendedSets: 3,
            recommendedReps: "5"
        )
        let cardioWE = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Run")),
            recommendedSets: 1,
            recommendedReps: "steady",
            cardioPrescription: CardioPrescription(kind: .steadyState, targetDurationSec: 600)
        )
        let workout = Workout(id: UUID(), name: "Legs", exercises: [strengthWE, cardioWE])
        vm.currentSession = WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date(),
            exerciseLogs: [
                ExerciseLog(id: UUID(), workoutExercise: strengthWE, loggedSets: []),
                ExerciseLog(id: UUID(), workoutExercise: cardioWE, loggedSets: [])
            ]
        )

        XCTAssertFalse(vm.shouldOfferCardioFinisherOnFinish())
    }

    func testShouldOfferCardioFinisher_strengthOnlyWithPostWorkoutPref_returnsTrue() throws {
        let saved = SplitBuilderPreferencesStore.load()
        defer { SplitBuilderPreferencesStore.save(saved) }
        var state = saved
        state.cardioPreferenceRaw = CardioProgramPreference.postWorkout.rawValue
        SplitBuilderPreferencesStore.save(state)

        let container = try makeInMemoryContainer()
        let dm = DataManager(modelContainer: container)
        let vm = CurrentWorkoutSessionViewModel(dataManager: dm)

        let strengthWE = WorkoutExercise(
            id: UUID(),
            resolution: .concrete(ExerciseSnapshot(exerciseId: UUID(), nameAtTimeOfLog: "Bench")),
            recommendedSets: 3,
            recommendedReps: "8"
        )
        let workout = Workout(id: UUID(), name: "Push", exercises: [strengthWE])
        vm.currentSession = WorkoutSession(
            id: UUID(),
            workout: workout,
            startTime: Date(),
            exerciseLogs: [ExerciseLog(id: UUID(), workoutExercise: strengthWE, loggedSets: [])]
        )

        XCTAssertTrue(vm.shouldOfferCardioFinisherOnFinish())
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV4.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
