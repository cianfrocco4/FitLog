//
//  ProgramPhaseGoalFactoryTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class ProgramPhaseGoalFactoryTests: XCTestCase {
    private func sampleBlock(focus: BlockFocusKind, deload: Bool = false, multiplier: Double = 1.0) -> ProgramBlock {
        ProgramBlock(
            name: "Phase",
            focus: BlockFocus(kind: focus, emphasisLabel: ""),
            durationWeeks: 4,
            weeklyTemplates: [
                BlockWeeklyTemplate(
                    dayName: "A",
                    focus: "",
                    slots: [
                        SplitBuilderEditableSlot(label: "Squat", targetMuscleNames: ["quads"], sets: 4, reps: "5"),
                        SplitBuilderEditableSlot(label: "Row", targetMuscleNames: ["back"], sets: 3, reps: "8"),
                    ]
                ),
                BlockWeeklyTemplate(
                    dayName: "B",
                    focus: "",
                    slots: [
                        SplitBuilderEditableSlot(label: "Bench", targetMuscleNames: ["chest"], sets: 4, reps: "5"),
                    ]
                ),
            ],
            isDeloadBlock: deload,
            volumeMultiplier: multiplier
        )
    }

    func testEachFocusYieldsPrimarySessionsTarget() {
        for kind in BlockFocusKind.allCases {
            let goal = ProgramPhaseGoalFactory.make(
                for: sampleBlock(focus: kind),
                sessionsPerWeek: 4,
                primaryGoal: .buildMuscle
            )
            XCTAssertEqual(goal.primaryTarget?.kind, .sessionsPerWeek, "Focus \(kind)")
            XCTAssertEqual(goal.primaryTarget?.value, 4)
            XCTAssertFalse(goal.targets.isEmpty)
        }
    }

    func testDeloadBlockScalesHardSets() {
        let normal = ProgramPhaseGoalFactory.make(
            for: sampleBlock(focus: .hypertrophy),
            sessionsPerWeek: 3
        )
        let deload = ProgramPhaseGoalFactory.make(
            for: sampleBlock(focus: .deload, deload: true, multiplier: 0.7),
            sessionsPerWeek: 3
        )
        let normalSets = normal.targets.first(where: { $0.kind == .weeklyHardSets })?.value ?? 0
        let deloadSets = deload.targets.first(where: { $0.kind == .weeklyHardSets })?.value ?? 0
        XCTAssertGreaterThan(normalSets, 0)
        XCTAssertLessThan(deloadSets, normalSets)
    }

    func testUserSetTargetsSurviveRenormalize() {
        var block = sampleBlock(focus: .strength)
        let initial = ProgramPhaseGoalFactory.make(for: block, sessionsPerWeek: 4, primaryGoal: .strength)
        var custom = initial
        if let idx = custom.targets.firstIndex(where: { $0.kind == .weeklyHardSets }) {
            custom.targets[idx].value = 99
            custom.targets[idx].source = .userSet
        }
        block.phaseGoal = custom
        // Change templates so auto hard sets would differ.
        block.weeklyTemplates[0].slots[0].sets = 1
        let renormalized = ProgramPhaseGoalFactory.make(
            for: block,
            sessionsPerWeek: 4,
            primaryGoal: .strength,
            existing: custom
        )
        XCTAssertEqual(renormalized.targets.first(where: { $0.kind == .weeklyHardSets })?.value, 99)
        XCTAssertEqual(renormalized.targets.first(where: { $0.kind == .weeklyHardSets })?.source, .userSet)
    }

    func testAttachingAutoGoalsFillsNilPhaseGoals() {
        let program = DynamicProgram(
            name: "Legacy",
            blocks: [sampleBlock(focus: .general)],
            defaultSessionsPerWeek: 3
        )
        XCTAssertNil(program.blocks[0].phaseGoal)
        let attached = ProgramPhaseGoalFactory.attachingAutoGoals(to: program, primaryGoal: .general)
        XCTAssertNotNil(attached.blocks[0].phaseGoal)
        XCTAssertEqual(attached.blocks[0].phaseGoal?.primaryTarget?.value, 3)
    }
}
