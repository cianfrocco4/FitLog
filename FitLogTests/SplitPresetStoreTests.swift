//
//  SplitPresetStoreTests.swift
//  FitLogTests
//
//  Tests for SplitPresetStore (Task 31).
//

import XCTest
import SwiftData
@testable import FitLog

final class SplitPresetStoreTests: XCTestCase {
    var modelContext: ModelContext!
    var store: SplitPresetStore!
    
    override func setUp() async throws {
        // Same as app: live `FitLogSchemaV3` + `cloudKitDatabase: .none`.
        let schema = Schema(versionedSchema: FitLogSchemaV3.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        store = SplitPresetStore(modelContext: modelContext)
    }
    
    override func tearDown() {
        modelContext = nil
        store = nil
    }
    
    func testSavePreset_CreatesRecords() {
        let days = [
            SplitBuilderEditableDay(
                id: UUID(),
                name: "Push",
                focus: "Chest, Shoulders, Triceps",
                slots: [
                    SplitBuilderEditableSlot(label: "Bench Press", targetMuscleNames: ["chest"], sets: 3, reps: "5")
                ]
            ),
            SplitBuilderEditableDay(
                id: UUID(),
                name: "Pull",
                focus: "Back, Biceps",
                slots: [
                    SplitBuilderEditableSlot(label: "Deadlift", targetMuscleNames: ["back"], sets: 3, reps: "5")
                ]
            )
        ]
        
        let preset = store.savePreset(
            name: "Push/Pull",
            notes: "Basic split",
            sessionsPerWeek: 2,
            preferredWeekdays: [2, 5],
            days: days
        )
        
        XCTAssertEqual(preset.name, "Push/Pull")
        XCTAssertEqual(preset.sessionsPerWeek, 2)
        XCTAssertEqual(preset.days.count, 2)
        XCTAssertEqual(preset.days[0].slots.count, 1)
    }
    
    func testLoadPresets_ReturnsAll() {
        _ = store.savePreset(name: "Split A", notes: "", sessionsPerWeek: 3, preferredWeekdays: [], days: [])
        _ = store.savePreset(name: "Split B", notes: "", sessionsPerWeek: 4, preferredWeekdays: [], days: [])
        
        let loaded = store.loadPresets()
        
        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains { $0.name == "Split A" })
        XCTAssertTrue(loaded.contains { $0.name == "Split B" })
    }
    
    func testToDomain_RoundTrips() {
        let originalDays = [
            SplitBuilderEditableDay(
                id: UUID(),
                name: "Legs",
                focus: "Quads, Hamstrings",
                slots: [
                    SplitBuilderEditableSlot(label: "Squat", targetMuscleNames: ["quadriceps"], sets: 4, reps: "5"),
                    SplitBuilderEditableSlot(label: "Leg Curl", targetMuscleNames: ["hamstrings"], sets: 3, reps: "10-12")
                ]
            )
        ]
        
        let preset = store.savePreset(
            name: "Leg Day",
            notes: "Heavy day",
            sessionsPerWeek: 1,
            preferredWeekdays: [3],
            days: originalDays
        )
        
        let (name, days, sessions, weekdays) = store.toDomain(preset)
        
        XCTAssertEqual(name, "Leg Day")
        XCTAssertEqual(sessions, 1)
        XCTAssertEqual(weekdays, [3])
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].name, "Legs")
        XCTAssertEqual(days[0].slots.count, 2)
        XCTAssertEqual(days[0].slots[0].label, "Squat")
    }
    
    func testDeletePreset_Removes() {
        let preset = store.savePreset(name: "Test", notes: "", sessionsPerWeek: 3, preferredWeekdays: [], days: [])
        
        store.deletePreset(preset)
        
        let loaded = store.loadPresets()
        XCTAssertTrue(loaded.isEmpty)
    }
}
