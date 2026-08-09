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
}
