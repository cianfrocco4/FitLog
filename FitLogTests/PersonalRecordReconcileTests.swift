//
//  PersonalRecordReconcileTests.swift
//  FitLogTests
//

import SwiftData
import XCTest
@testable import FitLog

final class PersonalRecordReconcileTests: XCTestCase {
    var modelContext: ModelContext!
    var store: PersonalRecordStore!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: SDPersonalRecordV2.self, configurations: config)
        modelContext = ModelContext(container)
        store = PersonalRecordStore(modelContext: modelContext)
    }

    override func tearDown() {
        modelContext = nil
        store = nil
    }

    func testReconcileBests_afterDeletingBestSet_restoresPreviousBest() {
        let exerciseId = UUID()
        let sessionId = UUID()
        let first = LoggedSet(
            id: UUID(),
            weight: 200,
            reps: 5,
            restTime: 90,
            timestamp: Date(),
            setType: .working
        )
        let second = LoggedSet(
            id: UUID(),
            weight: 225,
            reps: 5,
            restTime: 90,
            timestamp: Date().addingTimeInterval(120),
            setType: .working
        )

        _ = store.updateIfPR(set: first, exerciseId: exerciseId, exerciseName: "Bench", sessionId: sessionId)
        _ = store.updateIfPR(set: second, exerciseId: exerciseId, exerciseName: "Bench", sessionId: sessionId)

        store.reconcileBests(
            forExerciseId: exerciseId,
            fromSets: [(first, sessionId)],
            exerciseName: "Bench"
        )

        let (maxWeight, _, _) = store.bestValues(forExerciseId: exerciseId)
        XCTAssertEqual(maxWeight, 200)
    }

    func testReconcileBests_afterEditDowngradesPR() {
        let exerciseId = UUID()
        let sessionId = UUID()
        var set = LoggedSet(
            id: UUID(),
            weight: 225,
            reps: 5,
            restTime: 90,
            timestamp: Date(),
            setType: .working
        )
        _ = store.updateIfPR(set: set, exerciseId: exerciseId, exerciseName: "Squat", sessionId: sessionId)

        set.weight = 185
        store.reconcileBests(
            forExerciseId: exerciseId,
            fromSets: [(set, sessionId)],
            exerciseName: "Squat"
        )

        let (maxWeight, _, _) = store.bestValues(forExerciseId: exerciseId)
        XCTAssertEqual(maxWeight, 185)
    }
}
