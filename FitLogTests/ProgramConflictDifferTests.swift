//
//  ProgramConflictDifferTests.swift
//  FitLogTests
//
//  Tests for ProgramConflictDiffer (Task 31).
//

import XCTest
@testable import FitLog

@MainActor
final class ProgramConflictDifferTests: XCTestCase {
    func testDiff_EmptyProgram_NoConflict() {
        let proposedDays = [
            SplitBuilderEditableDay(id: UUID(), name: "Push", focus: "", slots: []),
            SplitBuilderEditableDay(id: UUID(), name: "Pull", focus: "", slots: [])
        ]
        
        let emptyProgram = TrainingProgramState(
            cycleEntries: [],
            sessionsPerWeek: 0,
            preferredWeekdays: [],
            anchorDayKey: "2026-01-01",
            cyclePhaseOffset: 0,
            skippedCycleTrainingDayKeys: [],
            dayOverrides: [:],
            weekOverrides: [:],
            frozenCalendarDays: [:]
        )
        
        let diff = ProgramConflictDiffer.diff(
            proposedDays: proposedDays,
            currentProgram: emptyProgram,
            currentWorkouts: []
        )
        
        XCTAssertFalse(diff.willReplaceCycle)
        XCTAssertEqual(diff.newTemplatesCreated, 2)
        XCTAssertEqual(diff.existingTemplatesKept, 0)
    }
    
    func testDiff_ExistingProgram_ShowsReplacement() {
        let proposedDays = [
            SplitBuilderEditableDay(id: UUID(), name: "Full Body", focus: "", slots: [])
        ]
        
        let existingProgram = TrainingProgramState(
            cycleEntries: [.workout(UUID()), .workout(UUID()), .workout(UUID())],
            sessionsPerWeek: 3,
            preferredWeekdays: [2, 4, 6],
            anchorDayKey: "2026-01-01",
            cyclePhaseOffset: 0,
            skippedCycleTrainingDayKeys: [],
            dayOverrides: [:],
            weekOverrides: [:],
            frozenCalendarDays: [:]
        )
        
        let diff = ProgramConflictDiffer.diff(
            proposedDays: proposedDays,
            currentProgram: existingProgram,
            currentWorkouts: []
        )
        
        XCTAssertTrue(diff.willReplaceCycle)
        XCTAssertEqual(diff.currentCycleCount, 3)
        XCTAssertEqual(diff.proposedCycleCount, 1)
    }
    
    func testDiff_MatchingWorkoutName_MarksAsExisting() {
        let pushWorkout = Workout(id: UUID(), name: "Push Day", exercises: [])
        
        let proposedDays = [
            SplitBuilderEditableDay(id: UUID(), name: "Push Day", focus: "", slots: []),
            SplitBuilderEditableDay(id: UUID(), name: "New Workout", focus: "", slots: [])
        ]
        
        let diff = ProgramConflictDiffer.diff(
            proposedDays: proposedDays,
            currentProgram: TrainingProgramState(
                cycleEntries: [],
                sessionsPerWeek: 0,
                preferredWeekdays: [],
                anchorDayKey: "2026-01-01",
                cyclePhaseOffset: 0,
                skippedCycleTrainingDayKeys: [],
                dayOverrides: [:],
                weekOverrides: [:],
                frozenCalendarDays: [:]
            ),
            currentWorkouts: [pushWorkout]
        )
        
        XCTAssertEqual(diff.existingTemplatesKept, 1)
        XCTAssertEqual(diff.newTemplatesCreated, 1)
        XCTAssertTrue(diff.templateDecisions[0].keepExisting)
        XCTAssertFalse(diff.templateDecisions[1].keepExisting)
    }
}
