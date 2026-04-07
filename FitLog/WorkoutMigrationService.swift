//
//  WorkoutMigrationService.swift
//  FitLog
//
//  One-time migration: legacy SDWorkoutTemplate rows become SDWorkout; optional id remap on collision.
//

import Foundation
import SwiftData

enum WorkoutMigrationService {
    static let migrationFlag = "unifiedWorkoutLibraryMigration_v1"

    static var needsMigration: Bool {
        !UserDefaults.standard.bool(forKey: migrationFlag)
    }

    static func migrateIfNeeded(context: ModelContext) {
        guard needsMigration else { return }

        do {
            try performMigration(context: context)
            UserDefaults.standard.set(true, forKey: migrationFlag)
            #if DEBUG
            print("[Migration] Unified workout library migration complete")
            #endif
        } catch {
            #if DEBUG
            print("[Migration] Unified workout library FAILED: \(error)")
            #endif
        }
    }

    private static func performMigration(context: ModelContext) throws {
        let templateDescriptor = FetchDescriptor<SDWorkoutTemplate>(sortBy: [SortDescriptor(\.sortOrder)])
        let sdTemplates = try context.fetch(templateDescriptor)
        guard !sdTemplates.isEmpty else {
            UserDefaults.standard.set(true, forKey: migrationFlag)
            return
        }

        let workoutDescriptor = FetchDescriptor<SDWorkout>(sortBy: [SortDescriptor(\.sortOrder)])
        let sdWorkouts = try context.fetch(workoutDescriptor)
        let existingIds = Set(sdWorkouts.map(\.workoutId))

        var idRemap: [UUID: UUID] = [:]
        let baseOrder = sdWorkouts.map(\.sortOrder).max() ?? -1

        for (i, sdT) in sdTemplates.enumerated() {
            let t = sdT.toStruct()
            let targetId: UUID
            if existingIds.contains(t.id) {
                let newId = UUID()
                idRemap[t.id] = newId
                targetId = newId
            } else {
                targetId = t.id
            }
            let converted = Workout.fromLegacyTemplate(WorkoutTemplate(id: targetId, name: t.name, slots: t.slots))
            context.insert(SDWorkout.from(converted, sortOrder: baseOrder + 1 + i))
        }

        if !idRemap.isEmpty {
            if let sdProg = try context.fetch(FetchDescriptor<SDTrainingProgram>()).first,
               var program = sdProg.toStruct() {
                program = program.remappingWorkoutPlanRefs(idRemap)
                try context.delete(model: SDTrainingProgram.self)
                context.insert(SDTrainingProgram.from(program))
            }

            let sessionDescriptor = FetchDescriptor<SDWorkoutSession>()
            let sessions = try context.fetch(sessionDescriptor)
            for sd in sessions {
                guard var s = sd.toStruct() else { continue }
                guard let o = s.sessionPlanOrigin, let newId = idRemap[o.libraryWorkoutId] else { continue }
                s.sessionPlanOrigin = .workout(newId)
                context.delete(sd)
                context.insert(SDWorkoutSession.from(s))
            }
        }

        for sd in sdTemplates {
            context.delete(sd)
        }

        try context.save()
    }
}
