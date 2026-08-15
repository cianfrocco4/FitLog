//
//  InlineLogSetAccessibilityTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct InlineLogSetAccessibilityTests {

    @Test func logSetLabel_includesExerciseWeightAndReps() {
        let label = InlineLogSetAccessibility.logSetLabel(
            exerciseName: "Bench Press",
            bodyweightMode: false,
            displayWeight: 135,
            reps: 8,
            unitLabel: "lb",
            formatWeight: { "\(Int($0))" }
        )
        #expect(label == "Log set, Bench Press, 135 lb, 8 reps")
    }

    @Test func logSetLabel_bodyweightMode_includesNetLoadWhenPresent() {
        let label = InlineLogSetAccessibility.logSetLabel(
            exerciseName: "Pull-Up",
            bodyweightMode: true,
            displayWeight: 25,
            reps: 6,
            unitLabel: "lb",
            formatWeight: { "\(Int($0))" }
        )
        #expect(label == "Log set, Pull-Up, +25 lb net, 6 reps")
    }

    @Test func logSetLabel_bodyweightMode_assistedUsesMinusSign() {
        let label = InlineLogSetAccessibility.logSetLabel(
            exerciseName: "Dip",
            bodyweightMode: true,
            displayWeight: -40,
            reps: 10,
            unitLabel: "lb",
            formatWeight: { "\(Int($0))" }
        )
        #expect(label == "Log set, Dip, −40 lb net, 10 reps")
    }

    @Test func logSetLabel_omitsMissingDraftValues() {
        let label = InlineLogSetAccessibility.logSetLabel(
            exerciseName: "Squat",
            bodyweightMode: false,
            displayWeight: 0,
            reps: 0,
            unitLabel: "lb",
            formatWeight: { "\(Int($0))" }
        )
        #expect(label == "Log set, Squat")
    }

    @Test func logSetHint_weightedMentionsWeight() {
        #expect(InlineLogSetAccessibility.logSetHint(bodyweightMode: false) == "Logs the entered weight and reps for this exercise")
    }

    @Test func logSetHint_bodyweightMentionsNetLoad() {
        #expect(InlineLogSetAccessibility.logSetHint(bodyweightMode: true) == "Logs the entered net load and reps for this exercise")
    }

    @Test func logSetDisabledHint_promptsForReps() {
        #expect(InlineLogSetAccessibility.logSetDisabledHint == "Enter reps greater than zero to log this set")
    }

    @Test func loggedSetAnnouncement_includesExerciseWeightAndReps() {
        let message = InlineLogSetAccessibility.loggedSetAnnouncement(
            exerciseName: "Bench Press",
            bodyweightMode: false,
            displayWeight: 135,
            reps: 8,
            unitLabel: "lb",
            formatWeight: { "\(Int($0))" }
        )
        #expect(message == "Logged set, Bench Press, 135 lb, 8 reps")
    }

    @Test func loggedSetAnnouncement_dropSegmentUsesDropVerb() {
        let message = InlineLogSetAccessibility.loggedSetAnnouncement(
            exerciseName: "Curl",
            bodyweightMode: false,
            displayWeight: 40,
            reps: 12,
            unitLabel: "lb",
            isDropSegment: true,
            formatWeight: { "\(Int($0))" }
        )
        #expect(message == "Logged drop, Curl, 40 lb, 12 reps")
    }

    @Test func loggedSetAnnouncement_bodyweightMode_includesNetLoad() {
        let message = InlineLogSetAccessibility.loggedSetAnnouncement(
            exerciseName: "Pull-Up",
            bodyweightMode: true,
            displayWeight: 25,
            reps: 6,
            unitLabel: "lb",
            formatWeight: { "\(Int($0))" }
        )
        #expect(message == "Logged set, Pull-Up, +25 lb net, 6 reps")
    }

    @Test func confirmEditAndDropCopy_explainsDisabledAndEnabled() {
        #expect(InlineLogSetAccessibility.confirmDisabledHint == "Enter reps greater than zero to save")
        #expect(InlineLogSetAccessibility.confirmEditSetLabel(setNumber: 3) == "Save edited set 3")
        #expect(InlineLogSetAccessibility.confirmEditSetHint == "Saves changes to this set")
        #expect(InlineLogSetAccessibility.confirmDropSegmentLabel == "Save drop segment")
        #expect(InlineLogSetAccessibility.confirmDropSegmentHint == "Saves this drop segment")
    }
}
