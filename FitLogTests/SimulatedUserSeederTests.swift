//
//  SimulatedUserSeederTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite @MainActor
struct SimulatedUserSeederTests {

    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!

    @Test func catalog_hasFiveDistinctPersonas() {
        #expect(FitLogSimulatedUserPersona.catalog.count == 5)
        #expect(Set(FitLogSimulatedUserPersona.catalog.map(\.rawValue)).count == 5)
        #expect(FitLogSimulatedUserPersona.newFree.isPremium == false)
        #expect(FitLogSimulatedUserPersona.returningFree.isPremium == false)
        #expect(FitLogSimulatedUserPersona.premiumLifter.isPremium == true)
        #expect(FitLogSimulatedUserPersona.cardioHobbyist.isPremium == false)
        #expect(FitLogSimulatedUserPersona.planFollower.isPremium == false)
        #expect(FitLogUITestLaunch.persona == nil)
        #expect(FitLogUITestLaunch.shouldResetStore == false)
    }

    @Test func newFree_leavesLibraryEmpty() throws {
        let dm = try makeSeeded(.newFree)
        #expect(dm.userWorkouts.isEmpty)
        #expect(dm.completedSessions.isEmpty)
        #expect(!dm.globalExercises.isEmpty)
    }

    @Test func returningFree_hasRecentAndOlderHistory() throws {
        let dm = try makeSeeded(.returningFree)
        #expect(dm.userWorkouts.count == 3)
        #expect(dm.userWorkouts.map(\.name).contains("Push A"))
        #expect(dm.completedSessions.count == 6)

        let cal = Calendar.current
        let recent = dm.completedSessions.filter { session in
            guard let end = session.endTime else { return false }
            return abs(cal.dateComponents([.day], from: end, to: now).day ?? 99) <= 14
        }
        let older = dm.completedSessions.filter { session in
            guard let end = session.endTime else { return false }
            return (cal.dateComponents([.day], from: end, to: now).day ?? 0) >= 30
        }
        #expect(recent.count == 4)
        #expect(older.count == 2)
        #expect(dm.userWorkouts.allSatisfy { !$0.exercises.isEmpty })
    }

    @Test func premiumLifter_hasDeepHistory() throws {
        let dm = try makeSeeded(.premiumLifter)
        #expect(dm.userWorkouts.count == 3)
        #expect(dm.completedSessions.count == 11)
    }

    @Test func cardioHobbyist_seedsZone2Workout() throws {
        let dm = try makeSeeded(.cardioHobbyist)
        #expect(dm.userWorkouts.count == 1)
        #expect(dm.userWorkouts.first?.name.contains("Zone 2") == true)
        #expect(dm.userWorkouts.first?.workoutKind == .cardio)
        #expect(dm.completedSessions.count == 2)
    }

    @Test func planFollower_assignsToday() throws {
        let dm = try makeSeeded(.planFollower)
        #expect(dm.userWorkouts.count == 1)
        let dayKey = TrainingProgramState.dayKey(for: now)
        #expect(dm.trainingProgram.dayOverrides[dayKey]?.intent == .workout)
        if case .workout(let id) = dm.trainingProgram.dayOverrides[dayKey]?.planRef {
            #expect(id == dm.userWorkouts.first?.id)
        } else {
            Issue.record("Expected today's override to point at the seeded workout")
        }
    }

    private func makeSeeded(_ persona: FitLogSimulatedUserPersona) throws -> DataManager {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let dm = DataManager(modelContainer: container)
        dm.eraseAllAppData(createSafetyBackup: false)
        FitLogSimulatedUserSeeder.seed(persona, into: dm, now: now)
        return dm
    }
}
