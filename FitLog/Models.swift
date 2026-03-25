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

// MARK: - Exercise metadata (slot matching, AI suggestions)

/// Broad movement role for filtering and slot criteria.
enum ExerciseRole: String, CaseIterable, Codable, Identifiable {
    case compound = "Compound"
    case accessory = "Accessory"
    case isolation = "Isolation"

    var id: String { rawValue }
}

/// Movement pattern for slot matching (optional on exercises and slots).
enum MovementPattern: String, CaseIterable, Codable, Identifiable {
    case horizontalPush = "Horizontal push"
    case verticalPush = "Vertical push"
    case horizontalPull = "Horizontal pull"
    case verticalPull = "Vertical pull"
    case squat = "Squat"
    case hinge = "Hinge"
    case lunge = "Lunge"
    case carry = "Carry"
    case rotation = "Rotation"
    case isolation = "Isolation / single-joint"
    case other = "Other"

    var id: String { rawValue }
}

/// What the training plan scheduled for this day (concrete workout definition vs slot blueprint).
enum WorkoutPlanRef: Equatable, Codable, Hashable {
    case concreteWorkout(UUID)
    case slotTemplate(UUID)

    var userFacingTypeLabel: String {
        switch self {
        case .concreteWorkout: return "Workout"
        case .slotTemplate: return "Flexible template"
        }
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
    /// Defaults to `.accessory` for legacy decoded exercises until backfill or user edit.
    var exerciseRole: ExerciseRole
    /// Optional movement pattern for slot matching; nil = unspecified.
    var movementPattern: MovementPattern?

    init(
        id: UUID,
        name: String,
        description: String,
        targetedMuscles: [MuscleGroup],
        isCustom: Bool = false,
        configurationOptions: [ExerciseConfigurationOption] = [],
        exerciseRole: ExerciseRole = .accessory,
        movementPattern: MovementPattern? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.targetedMuscles = targetedMuscles
        self.isCustom = isCustom
        self.configurationOptions = configurationOptions
        self.exerciseRole = exerciseRole
        self.movementPattern = movementPattern
    }

    /// Placeholder row before the user picks a real exercise for a template slot (unique `id` per row).
    static func unfilledSlotPlaceholder(label: String) -> Exercise {
        Exercise(
            id: UUID(),
            name: label.isEmpty ? "Choose exercise" : label,
            description: "",
            targetedMuscles: [],
            isCustom: false,
            configurationOptions: [],
            exerciseRole: .accessory,
            movementPattern: nil
        )
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
        if let raw = try? c.decode(String.self, forKey: .exerciseRole),
           let role = ExerciseRole(rawValue: raw) {
            exerciseRole = role
        } else {
            exerciseRole = .accessory
        }
        if let raw = try? c.decode(String.self, forKey: .movementPattern) {
            movementPattern = MovementPattern(rawValue: raw)
        } else {
            movementPattern = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(targetedMuscles.map(\.rawValue), forKey: .targetedMuscles)
        try c.encode(isCustom, forKey: .isCustom)
        try c.encode(configurationOptions, forKey: .configurationOptions)
        try c.encode(exerciseRole.rawValue, forKey: .exerciseRole)
        if let movementPattern {
            try c.encode(movementPattern.rawValue, forKey: .movementPattern)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, targetedMuscles, isCustom, configurationOptions, exerciseRole, movementPattern
    }
}

/// Lightweight reference to an exercise, stored inside sessions/history instead of the full Exercise.
struct ExerciseSnapshot: Codable, Equatable, Hashable {
    let exerciseId: UUID
    let nameAtTimeOfLog: String

    init(exerciseId: UUID, nameAtTimeOfLog: String) {
        self.exerciseId = exerciseId
        self.nameAtTimeOfLog = nameAtTimeOfLog
    }

    init(from exercise: Exercise) {
        self.exerciseId = exercise.id
        self.nameAtTimeOfLog = exercise.name
    }
}

/// Whether a workout exercise row has a concrete exercise or is waiting for the user to pick one.
enum SlotResolution: Codable, Equatable {
    case concrete(ExerciseSnapshot)
    case unresolved(slotLabel: String, templateSlotId: UUID)
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var resolution: SlotResolution
    var defaultRestTime: Int = 90
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
    var configurationFields: [String] = []
    var recommendedConfigBySet: [[String: String]] = []

    /// The snapshot for concrete rows; nil for unresolved slots.
    var snapshot: ExerciseSnapshot? {
        if case .concrete(let s) = resolution { return s }
        return nil
    }

    /// The exercise ID for concrete rows; nil for unresolved slots.
    var exerciseId: UUID? { snapshot?.exerciseId }

    var isSlotPlaceholder: Bool {
        if case .unresolved = resolution { return true }
        return false
    }

    var slotLabel: String {
        if case .unresolved(let label, _) = resolution { return label }
        return ""
    }

    var templateSlotId: UUID? {
        if case .unresolved(_, let id) = resolution { return id }
        return nil
    }

    // MARK: - Initializers

    init(id: UUID, resolution: SlotResolution, defaultRestTime: Int = 90, recommendedSets: Int = 3, recommendedReps: String = "8-12", configurationFields: [String] = [], recommendedConfigBySet: [[String: String]] = []) {
        self.id = id
        self.resolution = resolution
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
        self.configurationFields = configurationFields
        self.recommendedConfigBySet = recommendedConfigBySet
    }

    /// Convenience init from a full Exercise (snapshots it automatically).
    init(
        id: UUID,
        exercise: Exercise,
        defaultRestTime: Int = 90,
        recommendedSets: Int = 3,
        recommendedReps: String = "8-12",
        configurationFields: [String] = [],
        recommendedConfigBySet: [[String: String]] = [],
        isSlotPlaceholder: Bool = false,
        templateSlotId: UUID? = nil,
        slotLabel: String = ""
    ) {
        self.id = id
        if isSlotPlaceholder, let tid = templateSlotId {
            self.resolution = .unresolved(slotLabel: slotLabel, templateSlotId: tid)
        } else {
            self.resolution = .concrete(ExerciseSnapshot(from: exercise))
        }
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
        self.configurationFields = configurationFields
        self.recommendedConfigBySet = recommendedConfigBySet
    }

    // MARK: - Codable (backward-compatible with old full-Exercise and SlotResolution<Exercise> formats)

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)

        if let res = try? c.decode(SlotResolution.self, forKey: .resolution) {
            // Current format: resolution stores ExerciseSnapshot
            resolution = res
        } else if c.contains(.exercise) {
            // Legacy format: full Exercise object + isSlotPlaceholder flags
            let fullExercise = try c.decode(Exercise.self, forKey: .exercise)
            let placeholder = (try? c.decode(Bool.self, forKey: .isSlotPlaceholder)) ?? false
            let tid = try? c.decode(UUID.self, forKey: .templateSlotId)
            let label = (try? c.decode(String.self, forKey: .slotLabel)) ?? ""
            if placeholder, let tid {
                resolution = .unresolved(slotLabel: label, templateSlotId: tid)
            } else {
                resolution = .concrete(ExerciseSnapshot(from: fullExercise))
            }
        } else {
            resolution = .unresolved(slotLabel: "", templateSlotId: UUID())
        }

        defaultRestTime = (try? c.decode(Int.self, forKey: .defaultRestTime)) ?? 90
        recommendedSets = (try? c.decode(Int.self, forKey: .recommendedSets)) ?? 3
        recommendedReps = (try? c.decode(String.self, forKey: .recommendedReps)) ?? "8-12"
        configurationFields = (try? c.decode([String].self, forKey: .configurationFields)) ?? []
        recommendedConfigBySet = (try? c.decode([[String: String]].self, forKey: .recommendedConfigBySet)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(resolution, forKey: .resolution)
        try c.encode(defaultRestTime, forKey: .defaultRestTime)
        try c.encode(recommendedSets, forKey: .recommendedSets)
        try c.encode(recommendedReps, forKey: .recommendedReps)
        try c.encode(configurationFields, forKey: .configurationFields)
        try c.encode(recommendedConfigBySet, forKey: .recommendedConfigBySet)
        if isSlotPlaceholder { try c.encode(true, forKey: .isSlotPlaceholder) }
        if let tid = templateSlotId { try c.encode(tid, forKey: .templateSlotId) }
        let label = slotLabel
        if !label.isEmpty { try c.encode(label, forKey: .slotLabel) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, resolution, exercise, defaultRestTime, recommendedSets, recommendedReps
        case configurationFields, recommendedConfigBySet
        case isSlotPlaceholder, templateSlotId, slotLabel
    }
}

/// Slot blueprint stored separately from concrete [`Workout`](Workout) definitions (Option A).
struct TemplateSlot: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var label: String
    var targetedMuscles: [MuscleGroup]
    var exerciseRole: ExerciseRole?
    var movementPattern: MovementPattern?
    /// Suggested library exercise; user may pick another when resolving.
    var defaultExerciseId: UUID?
    var defaultRestTime: Int
    var recommendedSets: Int
    var recommendedReps: String

    init(
        id: UUID = UUID(),
        label: String,
        targetedMuscles: [MuscleGroup],
        exerciseRole: ExerciseRole? = nil,
        movementPattern: MovementPattern? = nil,
        defaultExerciseId: UUID? = nil,
        defaultRestTime: Int = 90,
        recommendedSets: Int = 3,
        recommendedReps: String = "8-12"
    ) {
        self.id = id
        self.label = label
        self.targetedMuscles = targetedMuscles
        self.exerciseRole = exerciseRole
        self.movementPattern = movementPattern
        self.defaultExerciseId = defaultExerciseId
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        let muscleStrings = (try? c.decode([String].self, forKey: .targetedMuscles)) ?? []
        targetedMuscles = muscleStrings.map { MuscleGroup(rawValue: $0) ?? .other }
        if let raw = try? c.decode(String.self, forKey: .exerciseRole) {
            exerciseRole = ExerciseRole(rawValue: raw)
        } else {
            exerciseRole = nil
        }
        if let raw = try? c.decode(String.self, forKey: .movementPattern) {
            movementPattern = MovementPattern(rawValue: raw)
        } else {
            movementPattern = nil
        }
        defaultExerciseId = try? c.decode(UUID.self, forKey: .defaultExerciseId)
        defaultRestTime = (try? c.decode(Int.self, forKey: .defaultRestTime)) ?? 90
        recommendedSets = (try? c.decode(Int.self, forKey: .recommendedSets)) ?? 3
        recommendedReps = (try? c.decode(String.self, forKey: .recommendedReps)) ?? "8-12"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(label, forKey: .label)
        try c.encode(targetedMuscles.map(\.rawValue), forKey: .targetedMuscles)
        if let exerciseRole { try c.encode(exerciseRole.rawValue, forKey: .exerciseRole) }
        if let movementPattern { try c.encode(movementPattern.rawValue, forKey: .movementPattern) }
        if let defaultExerciseId { try c.encode(defaultExerciseId, forKey: .defaultExerciseId) }
        try c.encode(defaultRestTime, forKey: .defaultRestTime)
        try c.encode(recommendedSets, forKey: .recommendedSets)
        try c.encode(recommendedReps, forKey: .recommendedReps)
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, targetedMuscles, exerciseRole, movementPattern, defaultExerciseId
        case defaultRestTime, recommendedSets, recommendedReps
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var slots: [TemplateSlot]
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
}

/// One step in a drop set after the top weight (same set, one rest after the full sequence).
struct DropSetSegment: Codable, Equatable, Hashable {
    var weight: Double
    var reps: Int
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
    /// Lighter loads after `weight` × `reps`, in order (optional).
    var dropSegments: [DropSetSegment]

    init(id: UUID, weight: Double, reps: Int, restTime: Int, timestamp: Date, isWarmup: Bool = false, configuration: [String: String] = [:], dropSegments: [DropSetSegment] = []) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.restTime = restTime
        self.timestamp = timestamp
        self.isWarmup = isWarmup
        self.configuration = configuration
        self.dropSegments = dropSegments
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
        dropSegments = (try? c.decode([DropSetSegment].self, forKey: .dropSegments)) ?? []
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
        if !dropSegments.isEmpty { try c.encode(dropSegments, forKey: .dropSegments) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, weight, reps, restTime, timestamp, isWarmup, configuration, dropSegments
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
    /// What the user started from (for History / Coach). Nil = legacy session before this field existed.
    var sessionPlanOrigin: WorkoutPlanRef?
    var isCompleted: Bool { endTime != nil }

    init(
        id: UUID,
        workout: Workout,
        startTime: Date,
        endTime: Date? = nil,
        exerciseLogs: [ExerciseLog],
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        sessionPlanOrigin: WorkoutPlanRef? = nil
    ) {
        self.id = id
        self.workout = workout
        self.startTime = startTime
        self.endTime = endTime
        self.exerciseLogs = exerciseLogs
        self.activeExerciseIds = activeExerciseIds
        self.completedExerciseIds = completedExerciseIds
        self.sessionPlanOrigin = sessionPlanOrigin
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workout = try c.decode(Workout.self, forKey: .workout)
        startTime = try c.decode(Date.self, forKey: .startTime)
        endTime = try? c.decode(Date.self, forKey: .endTime)
        exerciseLogs = (try? c.decode([ExerciseLog].self, forKey: .exerciseLogs)) ?? []
        activeExerciseIds = (try? c.decode([UUID].self, forKey: .activeExerciseIds)) ?? []
        completedExerciseIds = (try? c.decode([UUID].self, forKey: .completedExerciseIds)) ?? []
        sessionPlanOrigin = try? c.decode(WorkoutPlanRef.self, forKey: .sessionPlanOrigin)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(workout, forKey: .workout)
        try c.encode(startTime, forKey: .startTime)
        if let endTime { try c.encode(endTime, forKey: .endTime) }
        try c.encode(exerciseLogs, forKey: .exerciseLogs)
        if !activeExerciseIds.isEmpty { try c.encode(activeExerciseIds, forKey: .activeExerciseIds) }
        if !completedExerciseIds.isEmpty { try c.encode(completedExerciseIds, forKey: .completedExerciseIds) }
        if let sessionPlanOrigin { try c.encode(sessionPlanOrigin, forKey: .sessionPlanOrigin) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, workout, startTime, endTime, exerciseLogs, activeExerciseIds, completedExerciseIds, sessionPlanOrigin
    }
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

    /// Volume for analytics (top set + all drops).
    var totalVolumeLoad: Double {
        weight * Double(reps) + dropSegments.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Single-line summary for history / workout UI, e.g. `225 lb × 8 reps → 185 lb × 6 reps`.
    func weightRepsDisplaySummary(unit: String = "lb") -> String {
        func wStr(_ w: Double) -> String {
            w == floor(w) ? "\(Int(w))" : String(format: "%.1f", w)
        }
        func seg(_ w: Double, _ r: Int) -> String {
            let rw = r == 1 ? "rep" : "reps"
            return "\(wStr(w)) \(unit) × \(r) \(rw)"
        }
        var parts = [seg(weight, reps)]
        for d in dropSegments {
            parts.append("→ " + seg(d.weight, d.reps))
        }
        return parts.joined(separator: " ")
    }
}

