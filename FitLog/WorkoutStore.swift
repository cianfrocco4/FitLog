//
//  WorkoutStore.swift
//  FitLog
//
//  Workout and template CRUD. Now reads/writes V2 @Model rows and converts
//  with toDomain()/SDWorkoutV2.from(_:sortOrder:), exposing the same
//  [Workout] / [WorkoutTemplate] API used by DataManager.
//

import Foundation
import SwiftData

final class WorkoutStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Workouts

    func loadWorkouts() -> [Workout] {
        let descriptor = FetchDescriptor<SDWorkoutV2>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let sdWorkouts = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData V2] Loaded \(sdWorkouts.count) workouts")
        #endif
        return sdWorkouts.map { $0.toDomain() }
    }

    @discardableResult
    func saveWorkouts(_ workouts: [Workout]) -> Bool {
        do {
            try modelContext.delete(model: SDWorkoutV2.self)
            for (i, w) in workouts.enumerated() {
                modelContext.insert(SDWorkoutV2.from(w, sortOrder: i))
            }
            try modelContext.save()
            return true
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save workouts failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Slot templates (legacy compatibility layer)

    func loadWorkoutTemplates() -> [WorkoutTemplate] {
        // V2 stores all templates as library workouts (SDWorkoutV2 with flexible rows).
        // Return an empty array; callers that relied on SDWorkoutTemplate are already
        // migrated by WorkoutMigrationService before V2 is engaged.
        []
    }

    func saveWorkoutTemplates(_ templates: [WorkoutTemplate]) {
        // No-op in V2 — templates are represented as flexible library workouts.
    }

    // MARK: - Helpers

    func uniqueName(_ base: String, existingWorkoutNames: Set<String>, existingTemplateNames: Set<String>) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let root = trimmed.isEmpty ? "Workout" : trimmed
        if !existingWorkoutNames.contains(root), !existingTemplateNames.contains(root) { return root }
        var n = 2
        while existingWorkoutNames.contains("\(root) (\(n))") || existingTemplateNames.contains("\(root) (\(n))") {
            n += 1
        }
        return "\(root) (\(n))"
    }

    func instantiateWorkout(from template: WorkoutTemplate, globalExercises: [Exercise]) -> Workout {
        var exercises: [WorkoutExercise] = []
        var slotByRow: [UUID: UUID] = [:]
        for slot in template.slots {
            let weId = UUID()
            let resolvedFromDefault: Exercise? = {
                guard let defId = slot.defaultExerciseId else { return nil }
                return globalExercises.first { $0.id == defId }
            }()
            let blueprint = slot.asSlotBlueprint()
            let resolution: SlotResolution
            if let ex = resolvedFromDefault {
                resolution = .concrete(ExerciseSnapshot(from: ex))
            } else {
                resolution = .flexible(blueprint)
            }
            slotByRow[weId] = slot.id
            exercises.append(
                WorkoutExercise(
                    id: weId,
                    resolution: resolution,
                    defaultRestTime: slot.defaultRestTime,
                    recommendedSets: slot.recommendedSets,
                    recommendedReps: slot.recommendedReps
                )
            )
        }
        return Workout(id: UUID(), name: template.name, exercises: exercises, templateSlotIdByWorkoutExerciseId: slotByRow)
    }

    /// Session copy: new instance id and row ids when the library workout has flexible rows; otherwise the library workout as-is.
    func sessionInstance(from library: Workout, globalExercises: [Exercise]) -> Workout {
        guard library.hasFlexibleSlots else { return library }
        var exercises: [WorkoutExercise] = []
        var slotByRow: [UUID: UUID] = [:]
        for row in library.exercises {
            let weId = UUID()
            let resolution: SlotResolution
            switch row.resolution {
            case .concrete(let snap):
                resolution = .concrete(snap)
            case .flexible(let blueprint):
                let resolvedFromDefault: Exercise? = {
                    guard let defId = blueprint.defaultExerciseId else { return nil }
                    return globalExercises.first { $0.id == defId }
                }()
                if let ex = resolvedFromDefault {
                    resolution = .concrete(ExerciseSnapshot(from: ex))
                } else {
                    resolution = .flexible(blueprint)
                }
                slotByRow[weId] = blueprint.id
            }
            exercises.append(
                WorkoutExercise(
                    id: weId,
                    resolution: resolution,
                    defaultRestTime: row.defaultRestTime,
                    recommendedSets: row.recommendedSets,
                    recommendedReps: row.recommendedReps,
                    configurationFields: row.configurationFields,
                    recommendedConfigBySet: row.recommendedConfigBySet
                )
            )
        }
        return Workout(
            id: UUID(),
            name: library.name,
            exercises: exercises,
            templateSlotIdByWorkoutExerciseId: slotByRow
        )
    }
}
