//
//  Models.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import SwiftUI

/// Exhaustive list of muscle groups for categorizing exercises. Order of assignment = decreasing applicability (primary, secondary, tertiary).
enum MuscleGroup: String, CaseIterable, Codable, Identifiable {
    case chest = "Chest"
    case upperChest = "Upper Chest"
    case lowerChest = "Lower Chest"
    case frontDelts = "Front Delts"
    case sideDelts = "Side Delts"
    case rearDelts = "Rear Delts"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case brachialis = "Brachialis"
    case forearms = "Forearms"
    case lats = "Lats"
    case upperBack = "Upper Back"
    case midBack = "Mid Back"
    case rhomboids = "Rhomboids"
    case traps = "Traps"
    case lowerBack = "Lower Back"
    case posteriorChain = "Posterior Chain"
    case rotatorCuff = "Rotator Cuff"
    case abs = "Abs"
    case lowerAbs = "Lower Abs"
    case obliques = "Obliques"
    case core = "Core"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case soleus = "Soleus"
    case hipFlexors = "Hip Flexors"
    case adductors = "Adductors"
    case abductors = "Abductors"
    case neck = "Neck"
    case serratusAnterior = "Serratus Anterior"
    case other = "Other"
    
    var id: String { rawValue }
    
    /// All cases in display order (grouped logically for picker).
    static var displayOrder: [MuscleGroup] {
        [.chest, .upperChest, .lowerChest,
         .frontDelts, .sideDelts, .rearDelts,
         .biceps, .triceps, .brachialis, .forearms,
         .lats, .upperBack, .midBack, .rhomboids, .traps, .lowerBack, .posteriorChain,
         .rotatorCuff,
         .abs, .lowerAbs, .obliques, .core,
         .quads, .hamstrings, .glutes, .calves, .soleus,
         .hipFlexors, .adductors, .abductors,
         .neck, .serratusAnterior, .other]
    }
}

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var targetedMuscles: [MuscleGroup]
    /// True when the exercise was added by the user (editable/deletable in the library).
    var isCustom: Bool
    
    init(id: UUID, name: String, description: String, targetedMuscles: [MuscleGroup], isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.targetedMuscles = targetedMuscles
        self.isCustom = isCustom
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        let strings = try c.decode([String].self, forKey: .targetedMuscles)
        targetedMuscles = strings.map { MuscleGroup(rawValue: $0) ?? .other }
        isCustom = (try? c.decode(Bool.self, forKey: .isCustom)) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(targetedMuscles.map(\.rawValue), forKey: .targetedMuscles)
        try c.encode(isCustom, forKey: .isCustom)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, description, targetedMuscles, isCustom
    }
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var exercise: Exercise
    var defaultRestTime: Int = 90
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
}

struct LoggedSet: Identifiable, Codable {
    let id: UUID
    var weight: Double
    var reps: Int
    var restTime: Int
    var timestamp: Date
    var isWarmup: Bool = false
}

struct ExerciseLog: Identifiable, Codable {
    let id: UUID
    var workoutExercise: WorkoutExercise
    var loggedSets: [LoggedSet]
}

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    var workout: Workout
    var startTime: Date
    var endTime: Date?
    var exerciseLogs: [ExerciseLog]
    var isCompleted: Bool { endTime != nil }
}

