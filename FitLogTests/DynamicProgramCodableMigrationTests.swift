//
//  DynamicProgramCodableMigrationTests.swift
//  FitLogTests
//
//  Ensures pre–manual-builder JSON decodes after slot/block extensions.
//

import XCTest
@testable import FitLog

final class DynamicProgramCodableMigrationTests: XCTestCase {

    func testDecodeLegacySlotJSON() throws {
        let id = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        let json = """
        {"id":"33333333-4444-5555-6666-777777777777","label":"Press","targetMuscleNames":["chest"],"sets":4,"reps":"8-12","suggestedExerciseName":"Bench Press","suggestedExerciseOverrideId":null}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let slot = try JSONDecoder().decode(SplitBuilderEditableSlot.self, from: data)
        XCTAssertEqual(slot.id, id)
        XCTAssertEqual(slot.label, "Press")
        XCTAssertNil(slot.setScheme)
        XCTAssertFalse(slot.isWarmUp)
    }

    func testDecodeLegacyProgramBlockJSON() throws {
        let json = """
        {
          "id": "11111111-2222-3333-4444-555555555555",
          "name": "Block 1",
          "focus": { "kind": "general", "emphasisLabel": "" },
          "durationWeeks": 4,
          "weeklyTemplates": [
            {
              "id": "22222222-3333-4444-5555-666666666666",
              "dayName": "Push",
              "focus": "Chest",
              "slots": []
            }
          ],
          "progressionStrategy": "doubleProgression",
          "isDeloadBlock": false,
          "volumeMultiplier": 1.0
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let block = try JSONDecoder().decode(ProgramBlock.self, from: data)
        XCTAssertNil(block.deloadWeekNumber)
        XCTAssertNil(block.notes)
        XCTAssertNil(block.warmUpTemplate)
        XCTAssertNil(block.cooldownTemplate)
        XCTAssertNil(block.phaseGoal)
    }

    func testPhaseGoalSurvivesVersionedRoundTrip() throws {
        let goal = ProgramPhaseGoal(
            title: "Build muscle",
            summary: "Train 4×/week with about 16 hard sets.",
            targets: [
                ProgramGoalTarget(kind: .sessionsPerWeek, value: 4, isPrimary: true, source: .auto),
                ProgramGoalTarget(kind: .weeklyHardSets, value: 16, tolerance: 2, source: .userSet),
            ],
            copyIsUserSet: true
        )
        let block = ProgramBlock(
            name: "Hypertrophy",
            focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
            durationWeeks: 4,
            weeklyTemplates: [
                BlockWeeklyTemplate(dayName: "Push", focus: "Chest", slots: [])
            ],
            phaseGoal: goal
        )
        let program = DynamicProgram(
            name: "Goals",
            blocks: [block],
            defaultSessionsPerWeek: 4
        )
        let state = DynamicProgramState(program: program, anchorDate: Date(timeIntervalSince1970: 1_700_000_000))
        let blob = versionedEncode(state)
        let payload = try JSONDecoder().decode(VersionedPayload<DynamicProgramState>.self, from: blob)
        XCTAssertEqual(payload.schemaVersion, currentSchemaVersion)
        XCTAssertEqual(currentSchemaVersion, 7)
        let roundTrip = try XCTUnwrap(versionedDecode(DynamicProgramState.self, from: blob))
        let restored = try XCTUnwrap(roundTrip.program.blocks.first?.phaseGoal)
        XCTAssertEqual(restored.title, "Build muscle")
        XCTAssertEqual(restored.targets.first(where: { $0.kind == .weeklyHardSets })?.value, 16)
        XCTAssertEqual(restored.targets.first(where: { $0.kind == .weeklyHardSets })?.source, .userSet)
        XCTAssertTrue(restored.copyIsUserSet)
    }

    func testBackupSnapshotPreservesPhaseGoals() throws {
        let goal = ProgramPhaseGoal(
            title: "Get stronger",
            summary: "Hit planned sessions.",
            targets: [ProgramGoalTarget(kind: .sessionsPerWeek, value: 3, isPrimary: true)]
        )
        let program = DynamicProgram(
            name: "Backup Goals",
            blocks: [
                ProgramBlock(
                    name: "Strength",
                    focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                    durationWeeks: 4,
                    weeklyTemplates: [BlockWeeklyTemplate(dayName: "A", focus: "", slots: [])],
                    phaseGoal: goal
                ),
            ],
            defaultSessionsPerWeek: 3
        )
        let dynamic = DynamicProgramState(program: program, anchorDate: Date(timeIntervalSince1970: 1_700_000_000))
        let snapshot = BackupSnapshot(
            schemaVersion: currentSchemaVersion,
            exercises: [],
            workouts: [],
            sessions: [],
            program: TrainingProgramState.empty(anchorDayKey: "2026-03-02"),
            displayNames: [:],
            dynamicProgram: dynamic
        )
        let data = try DataTransferService.makeExportData(format: .json, snapshot: snapshot)
        let imported = try DataTransferService.importSnapshot(from: data, format: .json)
        XCTAssertEqual(imported.dynamicProgram?.program.blocks.first?.phaseGoal?.title, "Get stronger")
        XCTAssertEqual(
            imported.dynamicProgram?.program.blocks.first?.phaseGoal?.primaryTarget?.value,
            3
        )
    }

    func testVersionedEncodeRoundTripPreservesExtendedFields() throws {
        let slot = SplitBuilderEditableSlot(
            label: "Squat",
            targetMuscleNames: ["quads"],
            sets: 5,
            reps: "5",
            suggestedExerciseName: "Back Squat",
            setScheme: SetScheme(kind: .rpeBased, rpeTarget: 8),
            grouping: ExerciseGrouping(kind: .superset, partnerSlotIds: [UUID()]),
            notes: "Brace hard",
            isWarmUp: true
        )
        let template = BlockWeeklyTemplate(dayName: "Legs", focus: "Lower", slots: [slot], dayNotes: "Go heavy")
        let block = ProgramBlock(
            name: "Strength",
            focus: BlockFocus(kind: .strength, emphasisLabel: ""),
            durationWeeks: 4,
            weeklyTemplates: [template],
            deloadWeekNumber: 4,
            notes: "Block note",
            warmUpTemplate: [SplitBuilderEditableSlot(label: "Walk", targetMuscleNames: [], sets: 1, reps: "5 min")]
        )
        let program = DynamicProgram(
            name: "Full",
            blocks: [block],
            defaultSessionsPerWeek: 3,
            preferredWeekdays: [],
            busyDayPolicy: .compress
        )
        let state = DynamicProgramState(program: program, anchorDate: Date(timeIntervalSince1970: 1_700_000_000))
        let blob = versionedEncode(state)
        let roundTrip = try XCTUnwrap(versionedDecode(DynamicProgramState.self, from: blob))
        XCTAssertEqual(roundTrip.program.blocks[0].notes, "Block note")
        XCTAssertEqual(roundTrip.program.blocks[0].weeklyTemplates[0].dayNotes, "Go heavy")
        XCTAssertEqual(roundTrip.program.blocks[0].weeklyTemplates[0].slots[0].notes, "Brace hard")
        XCTAssertTrue(roundTrip.program.blocks[0].weeklyTemplates[0].slots[0].isWarmUp)
        XCTAssertEqual(roundTrip.program.blocks[0].weeklyTemplates[0].slots[0].setScheme?.kind, .rpeBased)
    }

    func testSetSchemeValidation() {
        XCTAssertNil(SetScheme(kind: .rpeBased, rpeTarget: 8).validationMessageIfInvalid())
        XCTAssertNotNil(SetScheme(kind: .rpeBased, rpeTarget: 15).validationMessageIfInvalid())
        XCTAssertNil(SetScheme(kind: .fixed).validationMessageIfInvalid())
    }
}
