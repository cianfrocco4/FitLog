//
//  ExerciseEntity.swift
//  FitLog
//
//  App Intents entity for exercises (Task 30).
//

import Foundation
import AppIntents

struct ExerciseEntity: AppEntity {
    let id: UUID
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Exercise")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = ExerciseEntityQuery()
}

struct ExerciseEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ExerciseEntity] {
        let library = FitLogIntentBridge.loadExerciseLibrary()
        return library
            .filter { identifiers.contains($0.id) }
            .map { ExerciseEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ExerciseEntity] {
        FitLogIntentBridge.loadExerciseLibrary()
            .prefix(25)
            .map { ExerciseEntity(id: $0.id, name: $0.name) }
    }
}
