//
//  ActiveExerciseRoundTests.swift
//  FitLogTests
//
//  Superset letters (A, B, C) must only appear when the user explicitly builds a round.
//

import Foundation
import Testing
@testable import FitLog

@Suite struct ActiveExerciseRoundTests {
    private let bench = UUID()
    private let row = UUID()
    private let curl = UUID()

    @Test func focusingAnotherExercise_doesNotCreateSuperset() {
        let updated = ActiveExerciseRound.makingPrimary(row, in: [bench])
        #expect(updated == [row])
        #expect(ActiveExerciseRound.isSupersetRound(updated) == false)
    }

    @Test func focusingWithinRound_reordersAndKeepsRound() {
        let updated = ActiveExerciseRound.makingPrimary(row, in: [bench, row, curl])
        #expect(updated == [row, bench, curl])
        #expect(ActiveExerciseRound.isSupersetRound(updated))
    }

    @Test func focusingOutsideRound_endsRound() {
        let updated = ActiveExerciseRound.makingPrimary(curl, in: [bench, row])
        #expect(updated == [curl])
    }

    @Test func addingExerciseToWorkout_doesNotCreateSuperset() {
        #expect(ActiveExerciseRound.afterAddingExerciseToWorkout(row, in: [bench]) == [bench])
        #expect(ActiveExerciseRound.afterAddingExerciseToWorkout(row, in: []) == [row])
    }

    @Test func togglingMembership_growsThenShrinksRound() {
        let added = ActiveExerciseRound.togglingSupersetMember(row, in: [bench])
        #expect(added == [bench, row])
        #expect(ActiveExerciseRound.isSupersetRound(added))

        let removed = ActiveExerciseRound.togglingSupersetMember(row, in: added)
        #expect(removed == [bench])
        #expect(ActiveExerciseRound.isSupersetRound(removed) == false)
    }

    @Test func togglingTheLoneFocusedExercise_doesNotClearFocus() {
        #expect(ActiveExerciseRound.togglingSupersetMember(bench, in: [bench]) == [bench])
    }

    @Test func endingRound_keepsOnlyCurrentExercise() {
        #expect(ActiveExerciseRound.endingSupersetRound(in: [bench, row, curl]) == [bench])
        #expect(ActiveExerciseRound.endingSupersetRound(in: []).isEmpty)
    }
}
