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

/// Optional per-exercise setting (e.g. grip variant, machine setting) tracked with each logged set.
struct ExerciseConfigurationOption: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    /// If non-empty, user picks from these; if nil/empty, free-form text.
    var choices: [String]

    init(id: UUID = UUID(), name: String, choices: [String] = []) {
        self.id = id
        self.name = name
        self.choices = choices
    }
}

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var targetedMuscles: [MuscleGroup]
    /// True when the exercise was added by the user (editable/deletable in the library).
    var isCustom: Bool
    /// Optional settings (e.g. grip, seat) that can be recorded per set.
    var configurationOptions: [ExerciseConfigurationOption]

    init(id: UUID, name: String, description: String, targetedMuscles: [MuscleGroup], isCustom: Bool = false, configurationOptions: [ExerciseConfigurationOption] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.targetedMuscles = targetedMuscles
        self.isCustom = isCustom
        self.configurationOptions = configurationOptions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        let strings = try c.decode([String].self, forKey: .targetedMuscles)
        targetedMuscles = strings.map { MuscleGroup(rawValue: $0) ?? .other }
        isCustom = (try? c.decode(Bool.self, forKey: .isCustom)) ?? false
        configurationOptions = (try? c.decode([ExerciseConfigurationOption].self, forKey: .configurationOptions)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(targetedMuscles.map(\.rawValue), forKey: .targetedMuscles)
        try c.encode(isCustom, forKey: .isCustom)
        try c.encode(configurationOptions, forKey: .configurationOptions)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, targetedMuscles, isCustom, configurationOptions
    }
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var exercise: Exercise
    var defaultRestTime: Int = 90
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
    /// Names of configuration fields for this exercise in this workout (e.g. ["Grip", "Seat"]).
    var configurationFields: [String] = []
    /// Recommended configuration values per set index, aligned with `recommendedSets`.
    /// Each entry is fieldName -> value (e.g. ["Grip": "Narrow"]).
    var recommendedConfigBySet: [[String: String]] = []

    init(id: UUID = UUID(), exercise: Exercise, defaultRestTime: Int = 90, recommendedSets: Int = 3, recommendedReps: String = "8-12", configurationFields: [String] = [], recommendedConfigBySet: [[String: String]] = []) {
        self.id = id
        self.exercise = exercise
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
        self.configurationFields = configurationFields
        self.recommendedConfigBySet = recommendedConfigBySet
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        exercise = try c.decode(Exercise.self, forKey: .exercise)
        defaultRestTime = (try? c.decode(Int.self, forKey: .defaultRestTime)) ?? 90
        recommendedSets = (try? c.decode(Int.self, forKey: .recommendedSets)) ?? 3
        recommendedReps = (try? c.decode(String.self, forKey: .recommendedReps)) ?? "8-12"
        configurationFields = (try? c.decode([String].self, forKey: .configurationFields)) ?? []
        recommendedConfigBySet = (try? c.decode([[String: String]].self, forKey: .recommendedConfigBySet)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, exercise, defaultRestTime, recommendedSets, recommendedReps, configurationFields, recommendedConfigBySet
    }
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
    /// Configuration fields that apply to every set in this workout (e.g. "RPE", "Energy Level").
    var workoutConfigurationFields: [String] = []

    init(id: UUID, name: String, exercises: [WorkoutExercise], workoutConfigurationFields: [String] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.workoutConfigurationFields = workoutConfigurationFields
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        exercises = try c.decode([WorkoutExercise].self, forKey: .exercises)
        workoutConfigurationFields = (try? c.decode([String].self, forKey: .workoutConfigurationFields)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, exercises, workoutConfigurationFields
    }
}

struct LoggedSet: Identifiable, Codable {
    let id: UUID
    var weight: Double
    var reps: Int
    var restTime: Int
    var timestamp: Date
    var isWarmup: Bool = false
    /// Option id (uuidString) -> chosen value. Only present when exercise has configuration options.
    var configuration: [String: String]

    init(id: UUID, weight: Double, reps: Int, restTime: Int, timestamp: Date, isWarmup: Bool = false, configuration: [String: String] = [:]) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.restTime = restTime
        self.timestamp = timestamp
        self.isWarmup = isWarmup
        self.configuration = configuration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        weight = try c.decode(Double.self, forKey: .weight)
        reps = try c.decode(Int.self, forKey: .reps)
        restTime = try c.decode(Int.self, forKey: .restTime)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        isWarmup = (try? c.decode(Bool.self, forKey: .isWarmup)) ?? false
        configuration = (try? c.decode([String: String].self, forKey: .configuration)) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(weight, forKey: .weight)
        try c.encode(reps, forKey: .reps)
        try c.encode(restTime, forKey: .restTime)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(isWarmup, forKey: .isWarmup)
        if !configuration.isEmpty { try c.encode(configuration, forKey: .configuration) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, weight, reps, restTime, timestamp, isWarmup, configuration
    }
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
    /// IDs of exercises in this workout that are currently considered \"active\" (in progress).
    var activeExerciseIds: [UUID] = []
    /// IDs of exercises in this workout that the user has explicitly marked as completed.
    var completedExerciseIds: [UUID] = []
    var isCompleted: Bool { endTime != nil }
}

extension LoggedSet {
    /// Human-readable summary of configuration (e.g. "Grip: Narrow, Seat: 2") using field names from the workout exercise.
    func configurationSummary(fieldNames: [String]) -> String {
        guard !configuration.isEmpty else { return "" }
        let parts = fieldNames.compactMap { name -> String? in
            guard let value = configuration[name], !value.isEmpty else { return nil }
            return "\(name): \(value)"
        }
        return parts.joined(separator: ", ")
    }
}

