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
