//
//  ExerciseSetupResolverTests.swift
//  FitLogTests
//
//  Machine variants are per-set setup on one exercise, so resolving fields and values matters.
//

import Foundation
import Testing
@testable import FitLog

@Suite struct ExerciseSetupResolverTests {
    @Test func fields_takePlanOrderThenLibraryExtras() {
        let fields = ExerciseSetupResolver.fields(
            planFields: ["Grip", "Seat"],
            libraryOptions: [
                ExerciseConfigurationOption(name: "Grip", choices: ["Wide", "Medium", "Narrow"]),
                ExerciseConfigurationOption(name: "Attachment", choices: ["V-handle"])
            ]
        )
        #expect(fields.map(\.name) == ["Grip", "Seat", "Attachment"])
        #expect(fields[0].choices == ["Wide", "Medium", "Narrow"])
        #expect(fields[1].choices.isEmpty)
    }

    @Test func fields_dedupeCaseInsensitivelyAndDropBlanks() {
        let fields = ExerciseSetupResolver.fields(
            planFields: ["grip", "  ", "Grip"],
            libraryOptions: [ExerciseConfigurationOption(name: "GRIP", choices: ["Wide"])]
        )
        #expect(fields.count == 1)
        #expect(fields[0].name == "grip")
        #expect(fields[0].choices == ["Wide"])
    }

    @Test func values_layerPlanThenLastSetThenExplicitChoice() {
        let values = ExerciseSetupResolver.values(
            setIndex: 1,
            recommendedConfigBySet: [["Grip": "Wide"], ["Grip": "Narrow", "Seat": "3"]],
            lastLoggedConfiguration: ["Grip": "Medium"],
            draft: ["Seat": "4"]
        )
        #expect(values["Grip"] == "Medium")
        #expect(values["Seat"] == "4")
    }

    @Test func values_dropClearedFieldsAndTolerateMissingSetIndex() {
        let values = ExerciseSetupResolver.values(
            setIndex: 7,
            recommendedConfigBySet: [["Grip": "Wide"]],
            lastLoggedConfiguration: ["Grip": "Wide"],
            draft: ["Grip": ""]
        )
        #expect(values.isEmpty)
    }

    @Test func summary_listsSetFieldsInFieldOrder() {
        let fields = [
            ExerciseSetupField(name: "Grip", choices: ["Wide"]),
            ExerciseSetupField(name: "Seat", choices: []),
            ExerciseSetupField(name: "Attachment", choices: [])
        ]
        let summary = ExerciseSetupResolver.summary(
            fields: fields,
            values: ["Seat": "3", "Grip": "Wide"]
        )
        #expect(summary == "Grip: Wide, Seat: 3")
    }

    @Test func seedFillsEmptyOptionsOnlyAndIsIdempotent() {
        var exercises = [
            Exercise(id: UUID(), name: "T-Bar Row", description: "", targetedMuscles: [.lats]),
            Exercise(
                id: UUID(),
                name: "Seated Cable Row",
                description: "",
                targetedMuscles: [.lats],
                configurationOptions: [ExerciseConfigurationOption(name: "My grip", choices: ["Custom"])]
            ),
            Exercise(id: UUID(), name: "Barbell Bicep Curl", description: "", targetedMuscles: [.biceps])
        ]

        #expect(ExerciseSetupOptionSeed.merge(into: &exercises))
        #expect(exercises[0].configurationOptions.first?.name == "Grip")
        #expect(exercises[1].configurationOptions.map(\.name) == ["My grip"])
        #expect(exercises[2].configurationOptions.isEmpty)
        #expect(ExerciseSetupOptionSeed.merge(into: &exercises) == false)
    }
}
