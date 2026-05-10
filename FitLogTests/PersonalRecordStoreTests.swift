//
//  PersonalRecordStoreTests.swift
//  FitLogTests
//
//  Tests for PersonalRecordStore (Task 31).
//

import XCTest
import SwiftData
@testable import FitLog

final class PersonalRecordStoreTests: XCTestCase {
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
    
    func testUpdateIfPR_FirstSet_CreatesRecord() {
        let exerciseId = UUID()
        let set = LoggedSet(
            id: UUID(),
            weight: 135.0,
            reps: 10,
            restTime: 90,
            timestamp: Date(),
            setType: .working
        )
        
        let events = store.updateIfPR(
            set: set,
            exerciseId: exerciseId,
            exerciseName: "Bench Press",
            sessionId: UUID()
        )
        
        XCTAssertEqual(events.count, 3, "First set should trigger 3 PRs: weight, volume, est1RM")
        XCTAssertTrue(events.contains { $0.kind == .maxWeight })
        XCTAssertTrue(events.contains { $0.kind == .maxVolumeSet })
        XCTAssertTrue(events.contains { $0.kind == .estimatedOneRM })
    }
    
    func testUpdateIfPR_LowerWeight_NoEvent() {
        let exerciseId = UUID()
        let firstSet = LoggedSet(id: UUID(), weight: 200.0, reps: 5, restTime: 90, timestamp: Date(), setType: .working)
        _ = store.updateIfPR(set: firstSet, exerciseId: exerciseId, exerciseName: "Squat", sessionId: UUID())
        
        let secondSet = LoggedSet(id: UUID(), weight: 150.0, reps: 10, restTime: 90, timestamp: Date().addingTimeInterval(300), setType: .working)
        let events = store.updateIfPR(set: secondSet, exerciseId: exerciseId, exerciseName: "Squat", sessionId: UUID())
        
        XCTAssertTrue(events.isEmpty, "Lower weight should not trigger PR")
    }
    
    func testBestValues_ReturnsMaximums() {
        let exerciseId = UUID()
        let sets = [
            LoggedSet(id: UUID(), weight: 100.0, reps: 10, restTime: 90, timestamp: Date(), setType: .working),
            LoggedSet(id: UUID(), weight: 150.0, reps: 5, restTime: 90, timestamp: Date().addingTimeInterval(300), setType: .working),
            LoggedSet(id: UUID(), weight: 120.0, reps: 8, restTime: 90, timestamp: Date().addingTimeInterval(600), setType: .working)
        ]
        
        for set in sets {
            _ = store.updateIfPR(set: set, exerciseId: exerciseId, exerciseName: "Deadlift", sessionId: UUID())
        }
        
        let (maxWeight, est1RM, maxVolume) = store.bestValues(forExerciseId: exerciseId)
        
        XCTAssertEqual(maxWeight, 150.0)
        XCTAssertNotNil(est1RM)
        XCTAssertNotNil(maxVolume)
    }
}
