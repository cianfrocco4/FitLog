//
//  ExerciseNameResolutionTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct ExerciseNameResolutionTests {

    private func ex(_ name: String) -> Exercise {
        Exercise(
            id: UUID(),
            name: name,
            description: "",
            targetedMuscles: [.chest],
            isCustom: false
        )
    }

    @Test func resolve_exactCaseInsensitive() {
        let library = [ex("Barbell Bench Press")]
        let r = ExerciseNameResolution.resolve(planName: "barbell bench press", library: library)
        #expect(r == .linked(library[0]))
    }

    @Test func resolve_extraWhitespace() {
        let library = [ex("Barbell Bench Press")]
        let r = ExerciseNameResolution.resolve(planName: "  Barbell   Bench  Press  ", library: library)
        #expect(r == .linked(library[0]))
    }

    @Test func resolve_typoCloseMatch() {
        let library = [ex("Barbell Bench Press")]
        let r = ExerciseNameResolution.resolve(planName: "Barbell Bench Pres", library: library)
        guard case .linked(let e) = r else {
            Issue.record("Expected linked, got \(String(describing: r))")
            return
        }
        #expect(e.name == "Barbell Bench Press")
    }

    @Test func resolve_unknownCreatesCustom() {
        let library = [ex("Barbell Bench Press")]
        let r = ExerciseNameResolution.resolve(planName: "Totally Made Up Lift XYZ", library: library)
        #expect(r == .createCustom(displayName: "Totally Made Up Lift XYZ"))
    }

    @Test func resolve_emptyReturnsNil() {
        let r = ExerciseNameResolution.resolve(planName: "   ", library: [ex("A")])
        #expect(r == nil)
    }

    @Test func resolveMuscleGroups_fuzzyQuad() {
        let m = ExerciseNameResolution.resolveMuscleGroups(from: ["quad"])
        #expect(m == [.quads])
    }

    @Test func resolveMuscleGroups_exactRaw() {
        let m = ExerciseNameResolution.resolveMuscleGroups(from: ["Hamstrings", " Chest "])
        #expect(m.contains(.hamstrings))
        #expect(m.contains(.chest))
    }
}
