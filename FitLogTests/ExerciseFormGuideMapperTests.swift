//
//  ExerciseFormGuideMapperTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@MainActor
struct ExerciseFormGuideMapperTests {

    @Test func bundledMappingJSON_loadsFromAppBundle() {
        let url = Bundle.main.url(forResource: "ExerciseFormGuideMapping", withExtension: "json")
        #expect(url != nil)

        guard let url,
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ExerciseFormGuideMappingFile.self, from: data)
        else {
            Issue.record("ExerciseFormGuideMapping.json could not be decoded from the app bundle")
            return
        }

        #expect(file.version >= 1)
        #expect(file.mappings.count >= 50)
        #expect(ExerciseFormGuideMapper.bundledMappingCount >= 50)
    }

    @Test func mapping_exactBuiltInName_returnsBundledQuery() {
        let exercise = Exercise(
            id: UUID(),
            name: "Barbell Bench Press",
            description: "",
            targetedMuscles: [.chest]
        )
        let mapping = ExerciseFormGuideMapper.mapping(for: exercise)
        #expect(mapping?.searchQuery == "Barbell Bench Press")
    }

    @Test func mapping_unknownExercise_fallsBackToCanonicalName() {
        let exercise = Exercise(
            id: UUID(),
            name: "Custom Landmine Rotation",
            description: "",
            targetedMuscles: [.obliques],
            isCustom: true
        )
        let mapping = ExerciseFormGuideMapper.mapping(for: exercise)
        #expect(mapping?.searchQuery == "Custom Landmine Rotation")
    }

    @Test func mapping_fuzzyMatch_findsBarbellRow() {
        let exercise = Exercise(
            id: UUID(),
            name: "Barbell Bent Over Row",
            description: "",
            targetedMuscles: [.upperBack]
        )
        let mapping = ExerciseFormGuideMapper.mapping(for: exercise)
        #expect(mapping?.searchQuery.localizedCaseInsensitiveContains("Row") == true)
    }
}
