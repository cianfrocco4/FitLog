//
//  DynamicProgramBuilderUndoTests.swift
//  FitLogTests
//
//  Baseline / undo / generation stage coverage for the program builder.
//

import XCTest
@testable import FitLog

@MainActor
final class DynamicProgramBuilderUndoTests: XCTestCase {

    private func makeProgram(dayName: String, slotLabel: String) -> (DynamicProgram, SplitBuilderEditableDay) {
        let day = SplitBuilderEditableDay(
            name: dayName,
            focus: "",
            slots: [
                SplitBuilderEditableSlot(label: slotLabel, targetMuscleNames: ["Chest"], sets: 4, reps: "6-8"),
            ]
        )
        let program = DynamicProgram(
            name: "Test",
            blocks: [
                ProgramBlock(
                    name: "Block 1",
                    focus: BlockFocus(kind: .hypertrophy),
                    durationWeeks: 4,
                    weeklyTemplates: [
                        BlockWeeklyTemplate(id: day.id, dayName: day.name, focus: day.focus, slots: day.slots)
                    ],
                    progressionStrategy: .linear
                ),
            ],
            defaultSessionsPerWeek: 3
        )
        return (program, day)
    }

    func testCaptureBaselineAndResetRestoresDays() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Push", slotLabel: "Bench")
        vm.generatedProgram = program
        vm.rebuildEditableDaysFromProgram()
        vm.captureGeneratedBaseline()

        XCTAssertTrue(vm.canResetToGenerated)
        XCTAssertFalse(vm.canUndo)

        vm.pushUndoSnapshot()
        vm.perBlockEditableDays[0][0].slots.removeAll()
        vm.commitStructuralEdit(banner: "Slot removed — Undo")

        XCTAssertTrue(vm.canUndo)
        XCTAssertTrue(vm.perBlockEditableDays[0][0].slots.isEmpty)

        XCTAssertTrue(vm.resetToGenerated())
        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.count, 1)
        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.first?.label, "Bench")
    }

    func testUndoLastEditRestoresPreviousSnapshot() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Pull", slotLabel: "Row")
        vm.generatedProgram = program
        vm.rebuildEditableDaysFromProgram()
        vm.captureGeneratedBaseline()

        vm.pushUndoSnapshot()
        _ = vm.addComplementarySlot(dayIndex: 0, label: "Pull accessory", muscles: ["Lats"])
        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.count, 2)

        XCTAssertTrue(vm.undoLastEdit())
        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.count, 1)
        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.first?.label, "Row")
    }

    func testGenerationStageResetClearsStatus() {
        let vm = DynamicProgramBuilderViewModel()
        vm.setGenerationStage(.connecting)
        XCTAssertEqual(vm.generationStage, .connecting)
        vm.setGenerationStage(.designing)
        XCTAssertEqual(vm.generationStage, .designing)
        vm.setGenerationStage(.finalizing)
        XCTAssertEqual(vm.generationStage, .finalizing)
        vm.setGenerationStage(.ready)
        XCTAssertEqual(vm.generationStage, .ready)
        vm.resetGenerationProgressUI()
        XCTAssertEqual(vm.generationStage, .idle)
        XCTAssertNil(vm.generationStatusMessage)
    }

    func testFieldBindingDoesNotPersistUntilCommit() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Push", slotLabel: "Bench")
        vm.generatedProgram = program
        vm.rebuildEditableDaysFromProgram()

        var days = vm.bindingForBlockDays(0).wrappedValue
        days[0].slots[0].label = "Incline Bench"
        vm.bindingForBlockDays(0).wrappedValue = days

        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots[0].label, "Incline Bench")
        XCTAssertEqual(vm.generatedProgram?.blocks[0].weeklyTemplates[0].slots[0].label, "Bench")

        vm.commitFieldEdit()
        XCTAssertEqual(vm.generatedProgram?.blocks[0].weeklyTemplates[0].slots[0].label, "Incline Bench")
    }

    func testApplyAddDeloadPhaseKeepsTotalWeeksAndIsUndoable() {
        let vm = DynamicProgramBuilderViewModel()
        let day = SplitBuilderEditableDay(
            name: "Full",
            focus: "",
            slots: [SplitBuilderEditableSlot(label: "Squat", targetMuscleNames: ["Quads"], sets: 3, reps: "8")]
        )
        vm.generatedProgram = DynamicProgram(
            name: "Long",
            blocks: [
                ProgramBlock(
                    name: "Build",
                    focus: BlockFocus(kind: .hypertrophy),
                    durationWeeks: 8,
                    weeklyTemplates: [
                        BlockWeeklyTemplate(id: day.id, dayName: day.name, focus: day.focus, slots: day.slots)
                    ],
                    progressionStrategy: .doubleProgression
                ),
            ],
            defaultSessionsPerWeek: 3
        )
        vm.rebuildEditableDaysFromProgram()
        vm.captureGeneratedBaseline()

        XCTAssertTrue(vm.applyAddDeloadPhase())
        XCTAssertEqual(vm.generatedProgram?.blocks.count, 2)
        XCTAssertEqual(vm.generatedProgram?.blocks[0].durationWeeks, 7)
        XCTAssertEqual(vm.generatedProgram?.blocks[1].durationWeeks, 1)
        XCTAssertTrue(vm.generatedProgram?.blocks[1].isDeloadBlock == true)
        XCTAssertEqual(
            (vm.generatedProgram?.blocks ?? []).reduce(0) { $0 + $1.durationWeeks },
            8
        )
        XCTAssertTrue(vm.programReviewSuggestions.allSatisfy { $0.action != .addDeloadPhase })

        XCTAssertTrue(vm.undoLastEdit())
        XCTAssertEqual(vm.generatedProgram?.blocks.count, 1)
        XCTAssertEqual(vm.generatedProgram?.blocks[0].durationWeeks, 8)
    }

    func testApplyRaiseWeeklyVolumeReachesTargetAndRespectsCap() {
        let vm = DynamicProgramBuilderViewModel()
        let day = SplitBuilderEditableDay(
            name: "Full",
            focus: "",
            slots: (0 ..< 12).map { index in
                SplitBuilderEditableSlot(
                    label: "Slot \(index)",
                    targetMuscleNames: ["Chest"],
                    sets: 2,
                    reps: "8-12"
                )
            }
        )
        vm.generatedProgram = DynamicProgram(
            name: "Low volume",
            blocks: [
                ProgramBlock(
                    name: "Build",
                    focus: BlockFocus(kind: .hypertrophy),
                    durationWeeks: 4,
                    weeklyTemplates: [
                        BlockWeeklyTemplate(id: day.id, dayName: day.name, focus: day.focus, slots: day.slots)
                    ],
                    progressionStrategy: .doubleProgression
                ),
            ],
            defaultSessionsPerWeek: 3
        )
        vm.rebuildEditableDaysFromProgram()
        vm.captureGeneratedBaseline()

        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.map(\.sets).reduce(0, +), 24)
        XCTAssertTrue(vm.applyRaiseWeeklyVolume(targetHardSets: 45, blockIndex: 0))
        let sets = vm.perBlockEditableDays[0][0].slots.map(\.sets)
        XCTAssertEqual(sets.reduce(0, +), 45)
        XCTAssertTrue(sets.allSatisfy { $0 <= 5 })
        XCTAssertTrue(vm.canUndo)

        // Cap prevents exceeding 5 sets/slot even when target is higher.
        XCTAssertTrue(vm.applyRaiseWeeklyVolume(targetHardSets: 100, blockIndex: 0))
        let capped = vm.perBlockEditableDays[0][0].slots.map(\.sets)
        XCTAssertEqual(capped.reduce(0, +), 60)
        XCTAssertTrue(capped.allSatisfy { $0 == 5 })

        // Every slot is at the cap, so there is nothing left to raise.
        let undoDepthBefore = vm.canUndo
        XCTAssertFalse(vm.applyRaiseWeeklyVolume(targetHardSets: 100, blockIndex: 0))
        XCTAssertEqual(vm.perBlockEditableDays[0][0].slots.map(\.sets).reduce(0, +), 60)
        XCTAssertEqual(vm.canUndo, undoDepthBefore)
    }

    func testUnsavedChangesTrackEditsRatherThanFirstSave() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Push", slotLabel: "Bench")

        XCTAssertFalse(vm.hasUnsavedProgramChanges, "No program means nothing to lose.")

        // A program loaded from Plan matches what is already saved.
        vm.hydrate(from: DynamicProgramState(program: program, anchorDate: Date()))
        XCTAssertFalse(vm.hasUnsavedProgramChanges)

        // Editing it does not, which is what the close guard needs to catch.
        var days = vm.bindingForBlockDays(0).wrappedValue
        days[0].slots[0].label = "Incline Bench"
        vm.bindingForBlockDays(0).wrappedValue = days
        vm.commitFieldEdit()
        XCTAssertTrue(vm.hasUnsavedProgramChanges)
    }

    func testStructuralEditOnSavedProgramCountsAsUnsaved() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Push", slotLabel: "Bench")
        vm.hydrate(from: DynamicProgramState(program: program, anchorDate: Date()))
        XCTAssertFalse(vm.hasUnsavedProgramChanges)

        _ = vm.addComplementarySlot(dayIndex: 0, label: "Fly", muscles: ["Chest"])
        XCTAssertTrue(vm.hasUnsavedProgramChanges)
    }

    func testUndoingBackToSavedContentClearsUnsavedState() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Push", slotLabel: "Bench")
        vm.hydrate(from: DynamicProgramState(program: program, anchorDate: Date()))

        _ = vm.addComplementarySlot(dayIndex: 0, label: "Fly", muscles: ["Chest"])
        XCTAssertTrue(vm.hasUnsavedProgramChanges)

        // Undoing every edit puts the program back in step with Plan, so closing is safe again.
        XCTAssertTrue(vm.undoLastEdit())
        XCTAssertFalse(vm.hasUnsavedProgramChanges)
    }

    func testUndoLeavesUncommittedFieldEditsMarkedUnsaved() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Push", slotLabel: "Bench")
        vm.hydrate(from: DynamicProgramState(program: program, anchorDate: Date()))

        var days = vm.bindingForBlockDays(0).wrappedValue
        days[0].slots[0].label = "Incline Bench"
        vm.bindingForBlockDays(0).wrappedValue = days
        vm.commitFieldEdit()

        _ = vm.addComplementarySlot(dayIndex: 0, label: "Fly", muscles: ["Chest"])
        // Undo only rewinds the slot addition; the earlier rename is still not in Plan.
        XCTAssertTrue(vm.undoLastEdit())
        XCTAssertTrue(vm.hasUnsavedProgramChanges)
    }

    func testFreshlyGeneratedProgramCountsAsUnsaved() {
        let vm = DynamicProgramBuilderViewModel()
        let (program, _) = makeProgram(dayName: "Pull", slotLabel: "Row")
        vm.generatedProgram = program
        vm.rebuildEditableDaysFromProgram()
        vm.captureGeneratedBaseline()

        XCTAssertTrue(vm.hasUnsavedProgramChanges)
    }
}
