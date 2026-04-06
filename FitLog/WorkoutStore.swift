//
//  WorkoutStore.swift
//  FitLog
//
//  Workout and template CRUD, extracted from DataManager.
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
        let descriptor = FetchDescriptor<SDWorkout>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let sdWorkouts = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData] Loaded \(sdWorkouts.count) workouts")
        #endif
        return sdWorkouts.map { $0.toStruct() }
    }

    func saveWorkouts(_ workouts: [Workout]) {
        do {
            try modelContext.delete(model: SDWorkout.self)
            for (i, w) in workouts.enumerated() {
                modelContext.insert(SDWorkout.from(w, sortOrder: i))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save workouts failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Slot templates

    func loadWorkoutTemplates() -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<SDWorkoutTemplate>()
        guard let sdTemplates = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData] Loaded \(sdTemplates.count) slot templates")
        #endif
        return sdTemplates.map { $0.toStruct() }
    }

    func saveWorkoutTemplates(_ templates: [WorkoutTemplate]) {
        do {
            try modelContext.delete(model: SDWorkoutTemplate.self)
            for (i, t) in templates.enumerated() {
                modelContext.insert(SDWorkoutTemplate.from(t, sortOrder: i))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save slot templates failed: \(error.localizedDescription)")
            #endif
        }
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
