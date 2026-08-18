//
//  SimulatedUserLivingDayTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite @MainActor
struct SimulatedUserLivingDayTests {

    /// Monday 17 Aug 2026.
    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!
    /// Tuesday 18 Aug 2026.
    private let tuesday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 12))!
    /// Wednesday 19 Aug 2026.
    private let wednesday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 12))!

    @Test func trainingWeekdays_matchCatalog() {
        #expect(FitLogSimulatedUserPersona.returningFree.isTrainingDay(on: monday))
        #expect(!FitLogSimulatedUserPersona.returningFree.isTrainingDay(on: tuesday))
        #expect(FitLogSimulatedUserPersona.newFree.isTrainingDay(on: tuesday))
        #expect(!FitLogSimulatedUserPersona.newFree.isTrainingDay(on: monday))
        #expect(FitLogSimulatedUserPersona.returningFree.persistentStoreFileName == "FitLogData-sim-returningFree.store")
    }

    @Test func restDay_doesNotLog() throws {
        let dm = try makeEmptyManager()
        let outcome = FitLogSimulatedUserLivingDay.runTick(
            .returningFree,
            into: dm,
            now: tuesday,
            writeTickLog: false
        )
        #expect(outcome == .restDay)
        #expect(dm.completedSessions.isEmpty)
        #expect(!dm.userWorkouts.isEmpty)
    }

    @Test func trainingDay_logsOnceThenIdempotent() throws {
        let dm = try makeEmptyManager()
        let first = FitLogSimulatedUserLivingDay.runTick(
            .returningFree,
            into: dm,
            now: monday,
            writeTickLog: false
        )
        #expect(first == .logged)
        #expect(dm.completedSessions.count == 1)

        let second = FitLogSimulatedUserLivingDay.runTick(
            .returningFree,
            into: dm,
            now: monday,
            writeTickLog: false
        )
        #expect(second == .alreadyLoggedToday)
        #expect(dm.completedSessions.count == 1)
    }

    @Test func nextTrainingDay_appendsHistory() throws {
        let dm = try makeEmptyManager()
        _ = FitLogSimulatedUserLivingDay.runTick(.returningFree, into: dm, now: monday, writeTickLog: false)
        let later = FitLogSimulatedUserLivingDay.runTick(
            .returningFree,
            into: dm,
            now: wednesday,
            writeTickLog: false
        )
        #expect(later == .logged)
        #expect(dm.completedSessions.count == 2)
        let names = Set(dm.completedSessions.map(\.workout.name))
        #expect(names.count >= 1)
    }

    @Test func newFree_createsPushAOnFirstTick() throws {
        let dm = try makeEmptyManager()
        #expect(dm.userWorkouts.isEmpty)
        let outcome = FitLogSimulatedUserLivingDay.runTick(
            .newFree,
            into: dm,
            now: tuesday,
            writeTickLog: false
        )
        #expect(outcome == .logged)
        #expect(dm.userWorkouts.map(\.name).contains("Push A"))
        #expect(dm.completedSessions.count == 1)
    }

    @Test func trainingDay_unloggableWorkout_isNotEmptyLibrary() throws {
        let dm = try makeEmptyManager()
        _ = dm.createWorkout(name: "Empty Shell")
        let outcome = FitLogSimulatedUserLivingDay.runTick(
            .returningFree,
            into: dm,
            now: monday,
            writeTickLog: false
        )
        #expect(outcome == .skippedUnloggableWorkout)
        #expect(!dm.userWorkouts.isEmpty)
        #expect(dm.completedSessions.isEmpty)
    }

    @Test func modelStoreFileName_defaultsWithoutLivingFlags() {
        #expect(FitLogUITestLaunch.modelStoreFileName == "FitLogData.store")
        #expect(!FitLogUITestLaunch.isDailyLiving)
        #expect(!FitLogUITestLaunch.usesPersistentPersonaStore)
        #expect(!FitLogUITestLaunch.shouldWriteReview)
    }

    private func makeEmptyManager() throws -> DataManager {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let dm = DataManager(modelContainer: container)
        dm.eraseAllAppData(createSafetyBackup: false)
        return dm
    }
}
