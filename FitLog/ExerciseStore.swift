//
//  ExerciseStore.swift
//  FitLog
//
//  Exercise library and display name management, extracted from DataManager.
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
        let descriptor = FetchDescriptor<SDExercise>()
        guard let sdExercises = try? modelContext.fetch(descriptor) else { return [] }
        #if DEBUG
        print("[SwiftData] Loaded \(sdExercises.count) exercises")
        #endif
        return sdExercises.map { $0.toStruct() }
    }

    func saveExercises(_ exercises: [Exercise]) {
        do {
            try modelContext.delete(model: SDExercise.self)
            for ex in exercises {
                modelContext.insert(SDExercise.from(ex))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save exercises failed: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Display names

    func loadDisplayNames() -> [UUID: String] {
        let descriptor = FetchDescriptor<SDExerciseDisplayName>()
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
            try modelContext.delete(model: SDExerciseDisplayName.self)
            for (id, name) in names {
                let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                modelContext.insert(SDExerciseDisplayName(exerciseId: id, customName: t))
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[SwiftData] Save display names failed: \(error.localizedDescription)")
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
