//
//  WorkoutCompletionLastWorkingSetTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite @MainActor
struct WorkoutCompletionLastWorkingSetTests {

    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 12))!

    @Test func caption_formatsLastWorkingWeightAndReps() {
        let line = WorkoutCompletionExerciseLine(
            exerciseName: "Bench Press",
            workingSetCount: 3,
            volumePounds: 555,
            newPRSetCount: 0,
            lastWeightPounds: 185,
            lastReps: 5
        )
        #expect(line.lastWorkingSetCaption(displayUnit: .pounds) == "Last 185 lb × 5")
        #expect(line.lastWorkingSetCaption(displayUnit: .kilograms)?.contains("× 5") == true)
    }

    @Test func lastWorkingSet_picksLatestVolumeSet() {
        let earlier = LoggedSet(
            id: UUID(),
            weight: 135,
            reps: 8,
            restTime: 60,
            timestamp: monday,
            setType: .working
        )
        let later = LoggedSet(
            id: UUID(),
            weight: 185,
            reps: 5,
            restTime: 90,
            timestamp: monday.addingTimeInterval(600),
            setType: .working
        )
        let warmup = LoggedSet(
            id: UUID(),
            weight: 95,
            reps: 10,
            restTime: 30,
            timestamp: monday.addingTimeInterval(900),
            setType: .warmup
        )
        let last = WorkoutCompletionExerciseLine.lastWorkingSet(from: [earlier, later, warmup])
        #expect(last?.weight == 185)
        #expect(last?.reps == 5)
    }

    @Test func breakdown_includesLastWorkingSetFromLoggedSession() throws {
        let dm = try makeEmptyManager()
        FitLogSimulatedUserSeeder.seedStrengthLibrary(
            into: dm,
            templates: Array(WorkoutQuickStartTemplate.all.prefix(1))
        )
        guard let workout = dm.userWorkouts.first else {
            Issue.record("Expected a seeded library workout")
            return
        }
        let logged = FitLogSimulatedUserSeeder.logCompletedWorkout(
            from: workout,
            endedAt: monday,
            into: dm,
            cardio: false,
            workingWeight: 185
        )
        #expect(logged)
        guard let session = dm.completedSessions.first else {
            Issue.record("Expected a completed session")
            return
        }

        let breakdown = dm.buildWorkoutCompletionBreakdown(session: session)
        #expect(!breakdown.lines.isEmpty)
        #expect(breakdown.lines.contains { $0.lastWeightPounds == 185 && $0.lastReps == 8 })

        let share = WorkoutCompletionSummary(
            id: session.id,
            workoutName: workout.name,
            durationSeconds: 3600,
            totalSets: 3,
            totalVolumePounds: 555,
            exercisesWithSets: 1,
            totalResolvedExercises: 1,
            personalRecordCount: 0,
            exerciseBreakdown: breakdown.lines,
            personalRecordHighlights: [],
            totalCardioDurationSeconds: 0,
            totalCardioDistanceMeters: 0,
            cardioSegmentCount: 0
        ).shareLines(displayUnit: .pounds)
        #expect(share.contains("Last 185 lb × 8"))
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
