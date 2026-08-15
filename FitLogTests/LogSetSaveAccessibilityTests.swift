//
//  LogSetSaveAccessibilityTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct LogSetSaveAccessibilityTests {

    @Test func canSave_requiresPositiveReps() {
        #expect(
            !LogSetSaveAccessibility.canSave(
                reps: 0,
                bodyweightMode: false,
                dropSetEnabled: false,
                hasValidDropSegments: true,
                isSaving: false
            )
        )
        #expect(
            LogSetSaveAccessibility.canSave(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: false,
                hasValidDropSegments: true,
                isSaving: false
            )
        )
    }

    @Test func canSave_dropSetRequiresValidSegmentsUnlessBodyweight() {
        #expect(
            !LogSetSaveAccessibility.canSave(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: true,
                hasValidDropSegments: false,
                isSaving: false
            )
        )
        #expect(
            LogSetSaveAccessibility.canSave(
                reps: 8,
                bodyweightMode: true,
                dropSetEnabled: true,
                hasValidDropSegments: false,
                isSaving: false
            )
        )
        #expect(
            LogSetSaveAccessibility.canSave(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: true,
                hasValidDropSegments: true,
                isSaving: false
            )
        )
    }

    @Test func canSave_blocksWhileSaving() {
        #expect(
            !LogSetSaveAccessibility.canSave(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: false,
                hasValidDropSegments: true,
                isSaving: true
            )
        )
    }

    @Test func saveHint_explainsDisabledReasons() {
        #expect(
            LogSetSaveAccessibility.saveHint(
                reps: 0,
                bodyweightMode: false,
                dropSetEnabled: false,
                hasValidDropSegments: true,
                isSaving: false
            ) == "Enter reps greater than zero to save"
        )
        #expect(
            LogSetSaveAccessibility.saveHint(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: true,
                hasValidDropSegments: false,
                isSaving: false
            ) == "Add at least one drop with reps greater than zero, or turn off drop set"
        )
        #expect(
            LogSetSaveAccessibility.saveHint(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: false,
                hasValidDropSegments: true,
                isSaving: true
            ) == "Saving your set"
        )
        #expect(
            LogSetSaveAccessibility.saveHint(
                reps: 8,
                bodyweightMode: false,
                dropSetEnabled: false,
                hasValidDropSegments: true,
                isSaving: false
            ) == "Saves this set and returns to the workout"
        )
    }

    @Test func visibleDisabledCaption_onlyWhenRepsMissing() {
        #expect(
            LogSetSaveAccessibility.visibleDisabledCaption(reps: 0, isSaving: false)
                == "Enter reps greater than 0 to save."
        )
        #expect(LogSetSaveAccessibility.visibleDisabledCaption(reps: 8, isSaving: false) == nil)
        #expect(LogSetSaveAccessibility.visibleDisabledCaption(reps: 0, isSaving: true) == nil)
    }
}
