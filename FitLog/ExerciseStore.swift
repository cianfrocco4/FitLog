//
//  ExerciseStore.swift
//  FitLog
//
//  Exercise library and display name management. Reads/writes SDExerciseV2 rows.
//

import Foundation
import SwiftData

final class ExerciseStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load / save

    func loadExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<SDExerciseV2>()
        guard let rows = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData V2] Loaded \(rows.count) exercises")
        #endif
        return rows.map { $0.toDomain() }
    }

    func saveExercises(_ exercises: [Exercise]) {
        do {
            try modelContext.delete(model: SDExerciseV2.self)
            for ex in exercises {
                modelContext.insert(SDExerciseV2.from(ex))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save exercises failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Display names

    func loadDisplayNames() -> [UUID: String] {
        let descriptor = FetchDescriptor<SDExerciseDisplayNameV2>()
        guard let records = try? modelContext.fetch(descriptor) else { return [:] }
        var out: [UUID: String] = [:]
        for r in records {
            let t = r.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { out[r.exerciseId] = t }
        }
        return out
    }

    func saveDisplayNames(_ names: [UUID: String]) {
        do {
            try modelContext.delete(model: SDExerciseDisplayNameV2.self)
            for (id, name) in names {
                let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                modelContext.insert(SDExerciseDisplayNameV2(exerciseId: id, customName: t))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData V2] Save display names failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Display name resolution

    func resolvedDisplayName(for exercise: Exercise, globalExercises: [Exercise], localNames: [UUID: String]) -> String {
        let canonical = globalExercises.first(where: { $0.id == exercise.id })?.name ?? exercise.name
        if let custom = localNames[exercise.id] {
            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return canonical
    }

    func displayName(for snapshot: ExerciseSnapshot, globalExercises: [Exercise], localNames: [UUID: String]) -> String {
        if let ex = globalExercises.first(where: { $0.id == snapshot.exerciseId }) {
            let s = resolvedDisplayName(for: ex, globalExercises: globalExercises, localNames: localNames)
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return s }
        }
        if let custom = localNames[snapshot.exerciseId] {
            let t = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        let snapName = snapshot.nameAtTimeOfLog.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapName.isEmpty { return snapshot.nameAtTimeOfLog }
        return "Exercise"
    }

    func displayName(for we: WorkoutExercise, globalExercises: [Exercise], localNames: [UUID: String]) -> String {
        switch we.resolution {
        case .concrete(let snap):
            return displayName(for: snap, globalExercises: globalExercises, localNames: localNames)
        case .flexible(let blueprint):
            if let defId = blueprint.defaultExerciseId,
               let ex = globalExercises.first(where: { $0.id == defId }) {
                return resolvedDisplayName(for: ex, globalExercises: globalExercises, localNames: localNames)
            }
            return blueprint.label.isEmpty ? "Choose exercise" : blueprint.label
        }
    }
}
