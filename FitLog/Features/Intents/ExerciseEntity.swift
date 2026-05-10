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
        // TODO: Load from DataManager's global exercises
        return []
    }
    
    func suggestedEntities() async throws -> [ExerciseEntity] {
        // TODO: Return recently used exercises
        return []
    }
}
