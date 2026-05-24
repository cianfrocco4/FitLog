//
//  CardioExerciseSeedTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct CardioExerciseSeedTests {

    @Test func seedCatalog_hasAtLeastFiftyExercises() {
        #expect(CardioExerciseSeed.allExercises().count >= 50)
    }

    @Test func seedCatalog_usesStableUniqueIDs() {
        let exercises = CardioExerciseSeed.allExercises()
        let ids = exercises.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func seedCatalog_allRowsAreCardioOrHybrid() {
        for ex in CardioExerciseSeed.allExercises() {
            #expect(ex.modality == .cardio || ex.modality == .hybrid)
            #expect(ex.cardioMetadata != nil)
            #expect(ex.isCustom == false)
        }
    }

    @Test func merge_isIdempotent() {
        var library = CardioExerciseSeed.allExercises()
        let firstCount = library.count
        let addedAgain = CardioExerciseSeed.merge(into: &library)
        #expect(addedAgain == false)
        #expect(library.count == firstCount)
    }

    @Test func merge_addsOnlyMissingSeedRows() {
        var library: [Exercise] = []
        #expect(CardioExerciseSeed.merge(into: &library))
        let afterFirst = library.count
        #expect(afterFirst >= 50)

        library.removeAll { $0.id == CardioExerciseSeed.allExercises().first!.id }
        #expect(CardioExerciseSeed.merge(into: &library))
        #expect(library.count == afterFirst)
    }

    @Test func activityGrouping_ordersByActivityKind() {
        let exercises = CardioExerciseSeed.allExercises()
        let sections = CardioExerciseCategoryGrouping.activitySections(exercises: exercises) { $0.name }
        #expect(!sections.isEmpty)
        #expect(sections.contains { $0.0 == .run })
        #expect(sections.allSatisfy { !$0.1.isEmpty })
    }
}
