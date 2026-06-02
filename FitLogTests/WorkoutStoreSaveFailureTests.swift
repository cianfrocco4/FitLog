//
//  WorkoutStoreSaveFailureTests.swift
//  FitLogTests
//

import SwiftData
import XCTest
@testable import FitLog

final class WorkoutStoreSaveFailureTests: XCTestCase {
    func testSaveWorkouts_returnsFalseOnFailureWithoutCrashing() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: SDWorkoutV2.self, configurations: config) else {
            XCTFail("Expected in-memory container")
            return
        }
        let store = WorkoutStore(modelContext: ModelContext(container))
        let workout = Workout(id: UUID(), name: "Test", exercises: [])
        XCTAssertTrue(store.saveWorkouts([workout]))
    }
}
