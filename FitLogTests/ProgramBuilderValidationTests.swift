//
//  ProgramBuilderValidationTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class ProgramBuilderValidationTests: XCTestCase {
    func testEmptyNameBlocksSave() {
        let day = SplitBuilderEditableDay(name: "Push", focus: "", slots: [
            SplitBuilderEditableSlot(label: "Bench", targetMuscleNames: ["chest"], sets: 3, reps: "8", suggestedExerciseName: "Bench", suggestedExerciseOverrideId: UUID()),
        ])
        let program = DynamicProgram(
            name: "OK",
            blocks: [
                ProgramBlock(
                    name: "B1",
                    focus: BlockFocus(kind: .general, emphasisLabel: ""),
                    durationWeeks: 4,
                    weeklyTemplates: [BlockWeeklyTemplate(dayName: "Push", focus: "", slots: day.slots)],
                    progressionStrategy: .doubleProgression
                ),
            ],
            defaultSessionsPerWeek: 4,
            preferredWeekdays: [],
            busyDayPolicy: .skip
        )
        let r = ProgramValidationResult.evaluate(
            programName: "   ",
            program: program,
            perBlockEditableDays: [[day]],
            balanceWarnings: []
        )
        XCTAssertFalse(r.canSaveToPlan)
        XCTAssertTrue(r.blockingIssues.contains(where: { $0.localizedCaseInsensitiveContains("program name") }))
    }

    func testEmptySlotsBlockSave() {
        let emptyDay = SplitBuilderEditableDay(name: "Legs", focus: "", slots: [])
        let program = DynamicProgram(
            name: "Leg block",
            blocks: [
                ProgramBlock(
                    name: "B1",
                    focus: BlockFocus(kind: .general, emphasisLabel: ""),
                    durationWeeks: 2,
                    weeklyTemplates: [BlockWeeklyTemplate(dayName: "Legs", focus: "", slots: [])],
                    progressionStrategy: .doubleProgression
                ),
            ],
            defaultSessionsPerWeek: 3,
            preferredWeekdays: [],
            busyDayPolicy: .skip
        )
        let r = ProgramValidationResult.evaluate(
            programName: "Leg block",
            program: program,
            perBlockEditableDays: [[emptyDay]],
            balanceWarnings: [],
            isManualMode: false
        )
        XCTAssertFalse(r.canSaveToPlan)
        XCTAssertTrue(r.blockingIssues.contains(where: { $0.contains("no exercise slots") }))
    }

    func testEmptySlotsAreWarningsInManualMode() {
        let emptyDay = SplitBuilderEditableDay(name: "Legs", focus: "", slots: [])
        let program = DynamicProgram(
            name: "Leg block",
            blocks: [
                ProgramBlock(
                    name: "B1",
                    focus: BlockFocus(kind: .general, emphasisLabel: ""),
                    durationWeeks: 2,
                    weeklyTemplates: [BlockWeeklyTemplate(dayName: "Legs", focus: "", slots: [])],
                    progressionStrategy: .doubleProgression
                ),
            ],
            defaultSessionsPerWeek: 3,
            preferredWeekdays: [],
            busyDayPolicy: .skip
        )
        let r = ProgramValidationResult.evaluate(
            programName: "Leg block",
            program: program,
            perBlockEditableDays: [[emptyDay]],
            balanceWarnings: [],
            isManualMode: true
        )
        XCTAssertTrue(r.canSaveToPlan)
        XCTAssertTrue(r.warningIssues.contains(where: { $0.contains("no exercise slots") }))
        XCTAssertFalse(r.blockingIssues.contains(where: { $0.contains("no exercise slots") }))
    }

    func testValidProgramPassesBlocking() {
        let slot = SplitBuilderEditableSlot(
            label: "Squat",
            targetMuscleNames: [MuscleGroup.quads.rawValue],
            sets: 4,
            reps: "5",
            suggestedExerciseName: "Squat",
            suggestedExerciseOverrideId: UUID()
        )
        let day = SplitBuilderEditableDay(name: "Leg", focus: "", slots: [slot])
        let program = DynamicProgram(
            name: "Strength meso",
            blocks: [
                ProgramBlock(
                    name: "B1",
                    focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                    durationWeeks: 4,
                    weeklyTemplates: [BlockWeeklyTemplate(dayName: "Leg", focus: "", slots: [slot])],
                    progressionStrategy: .linear
                ),
            ],
            defaultSessionsPerWeek: 3,
            preferredWeekdays: [2, 4, 6],
            busyDayPolicy: .compress
        )
        let r = ProgramValidationResult.evaluate(
            programName: "Strength meso",
            program: program,
            perBlockEditableDays: [[day]],
            balanceWarnings: []
        )
        XCTAssertTrue(r.canSaveToPlan)
    }

    func testBalanceWarningIdsRemainDistinctAcrossDays() {
        let a = SplitProposalProgramWarning(
            severity: .note,
            message: "Thin day",
            dayIndex: 0,
            suggestion: .openDay(0)
        )
        let b = SplitProposalProgramWarning(
            severity: .note,
            message: "Thin day",
            dayIndex: 1,
            suggestion: .openDay(1)
        )
        XCTAssertNotEqual(a.id, b.id)

        let days = [
            SplitProposalProgramAnalyzer.DayInput(
                name: "Push",
                focus: "",
                slots: [
                    .init(label: "Bench", targetMuscleNames: [MuscleGroup.chest.rawValue], sets: 4),
                    .init(label: "OHP", targetMuscleNames: [MuscleGroup.frontDelts.rawValue], sets: 3),
                    .init(label: "Fly", targetMuscleNames: [MuscleGroup.chest.rawValue], sets: 3),
                ]
            ),
            SplitProposalProgramAnalyzer.DayInput(
                name: "Pull",
                focus: "",
                slots: [
                    .init(label: "Row", targetMuscleNames: [MuscleGroup.lats.rawValue], sets: 1),
                ]
            ),
        ]
        let stats = SplitProposalProgramAnalyzer.stats(for: days)
        let warnings = SplitProposalProgramAnalyzer.warnings(
            stats: stats,
            days: days,
            context: .init(sessionDurationMinutes: 60)
        )
        XCTAssertTrue(warnings.contains(where: { $0.dayIndex != nil || $0.suggestion != nil }))
    }
}
