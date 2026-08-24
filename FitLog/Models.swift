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

/// What the training plan scheduled for this day (single library workout id).
enum WorkoutPlanRef: Equatable, Hashable {
    /// Library [`Workout`](Workout) id (fixed exercises and/or flexible slot rows).
    case workout(UUID)

    var userFacingTypeLabel: String {
        "Workout"
    }

    var cacheKey: String {
        switch self {
        case .workout(let id): return "w-\(id.uuidString)"
        }
    }

    /// The library workout id this reference points at.
    var libraryWorkoutId: UUID {
        switch self {
        case .workout(let id): return id
        }
    }
}

extension WorkoutPlanRef: Codable {
    private enum CodingKeys: String, CodingKey {
        case workout
        case concreteWorkout
        case slotTemplate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try c.decodeIfPresent(UUID.self, forKey: .workout) {
            self = .workout(id)
            return
        }
        if let id = try c.decodeIfPresent(UUID.self, forKey: .concreteWorkout) {
            self = .workout(id)
            return
        }
        if let id = try c.decodeIfPresent(UUID.self, forKey: .slotTemplate) {
            self = .workout(id)
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "WorkoutPlanRef missing known keys")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .workout(let id):
            try c.encode(id, forKey: .workout)
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
    /// Strength by default for legacy exercises and bundled library rows.
    var modality: ExerciseModality
    /// Populated when `modality` is `.cardio` or `.hybrid`.
    var cardioMetadata: CardioExerciseMetadata?

    init(
        id: UUID,
        name: String,
        description: String,
        targetedMuscles: [MuscleGroup],
        isCustom: Bool = false,
        configurationOptions: [ExerciseConfigurationOption] = [],
        exerciseRole: ExerciseRole = .accessory,
        movementPattern: MovementPattern? = nil,
        modality: ExerciseModality = .strength,
        cardioMetadata: CardioExerciseMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.targetedMuscles = targetedMuscles
        self.isCustom = isCustom
        self.configurationOptions = configurationOptions
        self.exerciseRole = exerciseRole
        self.movementPattern = movementPattern
        self.modality = modality
        self.cardioMetadata = cardioMetadata
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
        if let raw = try? c.decode(String.self, forKey: .modality),
           let decoded = ExerciseModality(rawValue: raw) {
            modality = decoded
        } else {
            modality = .strength
        }
        cardioMetadata = try c.decodeIfPresent(CardioExerciseMetadata.self, forKey: .cardioMetadata)
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
        if modality != .strength {
            try c.encode(modality.rawValue, forKey: .modality)
        }
        if let cardioMetadata {
            try c.encode(cardioMetadata, forKey: .cardioMetadata)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, description, targetedMuscles, isCustom, configurationOptions, exerciseRole, movementPattern
        case modality, cardioMetadata
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

    private enum CodingKeys: String, CodingKey {
        case exerciseId
        case nameAtTimeOfLog
        case id
        case name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let eid = try c.decodeIfPresent(UUID.self, forKey: .exerciseId) {
            exerciseId = eid
        } else if let legacy = try c.decodeIfPresent(UUID.self, forKey: .id) {
            exerciseId = legacy
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.exerciseId,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "ExerciseSnapshot requires exerciseId or id")
            )
        }
        let ntLogRaw = try c.decodeIfPresent(String.self, forKey: .nameAtTimeOfLog)
        let nameRaw = try c.decodeIfPresent(String.self, forKey: .name)
        let ntLog = (ntLogRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nm = (nameRaw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        nameAtTimeOfLog = !ntLog.isEmpty ? ntLog : nm
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exerciseId, forKey: .exerciseId)
        try c.encode(nameAtTimeOfLog, forKey: .nameAtTimeOfLog)
    }
}

/// Criteria and defaults for a flexible row inside a library [`Workout`](Workout) (replaces standalone template slots on disk).
struct SlotBlueprint: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var label: String
    var targetedMuscles: [MuscleGroup]
    var exerciseRole: ExerciseRole?
    var movementPattern: MovementPattern?
    var defaultExerciseId: UUID?
    var defaultRestTime: Int
    var recommendedSets: Int
    var recommendedReps: String
    /// Cardio prescription for flexible slot rows; nil for strength-only slots.
    var cardioPrescription: CardioPrescription?

    init(
        id: UUID = UUID(),
        label: String,
        targetedMuscles: [MuscleGroup],
        exerciseRole: ExerciseRole? = nil,
        movementPattern: MovementPattern? = nil,
        defaultExerciseId: UUID? = nil,
        defaultRestTime: Int = 90,
        recommendedSets: Int = 3,
        recommendedReps: String = "8-12",
        cardioPrescription: CardioPrescription? = nil
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
        self.cardioPrescription = cardioPrescription
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
        cardioPrescription = try c.decodeIfPresent(CardioPrescription.self, forKey: .cardioPrescription)
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
        if let cardioPrescription { try c.encode(cardioPrescription, forKey: .cardioPrescription) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, targetedMuscles, exerciseRole, movementPattern, defaultExerciseId
        case defaultRestTime, recommendedSets, recommendedReps, cardioPrescription
    }
}

/// Whether a workout exercise row has a concrete exercise or is waiting for the user to pick one.
enum SlotResolution: Equatable, Hashable {
    case concrete(ExerciseSnapshot)
    case flexible(SlotBlueprint)
}

extension SlotResolution: Codable {
    private enum CodingKeys: String, CodingKey {
        case concrete
        case flexible
        case unresolved
    }

    private struct LegacyUnresolved: Codable {
        var slotLabel: String
        var templateSlotId: UUID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.flexible) {
            self = .flexible(try c.decode(SlotBlueprint.self, forKey: .flexible))
            return
        }
        if c.contains(.concrete) {
            if let snap = try? c.decode(ExerciseSnapshot.self, forKey: .concrete) {
                self = .concrete(snap)
                return
            }
            // Legacy: full Exercise embedded under `concrete` before snapshots were used everywhere.
            let ex = try c.decode(Exercise.self, forKey: .concrete)
            self = .concrete(ExerciseSnapshot(from: ex))
            return
        }
        if c.contains(.unresolved) {
            let leg = try c.decode(LegacyUnresolved.self, forKey: .unresolved)
            self = .flexible(
                SlotBlueprint(
                    id: leg.templateSlotId,
                    label: leg.slotLabel,
                    targetedMuscles: [],
                    exerciseRole: nil,
                    movementPattern: nil,
                    defaultExerciseId: nil,
                    defaultRestTime: 90,
                    recommendedSets: 3,
                    recommendedReps: "8-12"
                )
            )
            return
        }
        throw DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "SlotResolution: unknown payload")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .concrete(let snap):
            try c.encode(snap, forKey: .concrete)
        case .flexible(let blueprint):
            try c.encode(blueprint, forKey: .flexible)
        }
    }
}

struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var resolution: SlotResolution
    /// Decoded from legacy JSON only; cleared when the parent [`Workout`](Workout) normalizes slot bindings.
    var originSlotId: UUID?
    var defaultRestTime: Int = 90
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
    var configurationFields: [String] = []
    var recommendedConfigBySet: [[String: String]] = []
    /// Cardio prescription for this row; when set, logger uses cardio UI instead of weight/reps.
    var cardioPrescription: CardioPrescription?

    /// The snapshot for concrete rows; nil for unresolved slots.
    var snapshot: ExerciseSnapshot? {
        if case .concrete(let s) = resolution { return s }
        return nil
    }

    /// Resolved library exercise id: concrete snapshot, or flexible row default when set.
    var exerciseId: UUID? {
        if case .concrete(let s) = resolution { return s.exerciseId }
        if case .flexible(let b) = resolution { return b.defaultExerciseId }
        return nil
    }

    /// Flexible row with no default exercise yet (user picks each time / must resolve in session).
    var isOpenSlot: Bool {
        if case .flexible(let b) = resolution { return b.defaultExerciseId == nil }
        return false
    }

    /// Same as `isOpenSlot` (legacy name used across the app).
    var isSlotPlaceholder: Bool { isOpenSlot }

    var slotLabel: String {
        if case .flexible(let b) = resolution { return b.label }
        return ""
    }

    var templateSlotId: UUID? {
        if case .flexible(let b) = resolution { return b.id }
        return nil
    }

    /// Full slot criteria when this row is flexible; nil for concrete rows.
    var slotBlueprint: SlotBlueprint? {
        if case .flexible(let b) = resolution { return b }
        return nil
    }

    /// Row-level prescription, falling back to flexible slot blueprint prescription.
    var effectiveCardioPrescription: CardioPrescription? {
        cardioPrescription ?? slotBlueprint?.cardioPrescription
    }

    // MARK: - Initializers

    init(id: UUID, resolution: SlotResolution, defaultRestTime: Int = 90, recommendedSets: Int = 3, recommendedReps: String = "8-12", configurationFields: [String] = [], recommendedConfigBySet: [[String: String]] = [], cardioPrescription: CardioPrescription? = nil) {
        self.id = id
        self.resolution = resolution
        self.originSlotId = nil
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
        self.configurationFields = configurationFields
        self.recommendedConfigBySet = recommendedConfigBySet
        self.cardioPrescription = cardioPrescription
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
        slotLabel: String = "",
        cardioPrescription: CardioPrescription? = nil
    ) {
        self.id = id
        if isSlotPlaceholder, let tid = templateSlotId {
            self.resolution = .flexible(
                SlotBlueprint(
                    id: tid,
                    label: slotLabel,
                    targetedMuscles: [],
                    exerciseRole: nil,
                    movementPattern: nil,
                    defaultExerciseId: nil,
                    defaultRestTime: defaultRestTime,
                    recommendedSets: recommendedSets,
                    recommendedReps: recommendedReps
                )
            )
        } else {
            self.resolution = .concrete(ExerciseSnapshot(from: exercise))
        }
        self.originSlotId = nil
        self.defaultRestTime = defaultRestTime
        self.recommendedSets = recommendedSets
        self.recommendedReps = recommendedReps
        self.configurationFields = configurationFields
        self.recommendedConfigBySet = recommendedConfigBySet
        self.cardioPrescription = cardioPrescription
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
                resolution = .flexible(
                    SlotBlueprint(
                        id: tid,
                        label: label,
                        targetedMuscles: [],
                        exerciseRole: nil,
                        movementPattern: nil,
                        defaultExerciseId: nil,
                        defaultRestTime: (try? c.decode(Int.self, forKey: .defaultRestTime)) ?? 90,
                        recommendedSets: (try? c.decode(Int.self, forKey: .recommendedSets)) ?? 3,
                        recommendedReps: (try? c.decode(String.self, forKey: .recommendedReps)) ?? "8-12"
                    )
                )
            } else {
                resolution = .concrete(ExerciseSnapshot(from: fullExercise))
            }
        } else {
            resolution = .flexible(
                SlotBlueprint(id: UUID(), label: "", targetedMuscles: [], exerciseRole: nil, movementPattern: nil, defaultExerciseId: nil)
            )
        }

        defaultRestTime = (try? c.decode(Int.self, forKey: .defaultRestTime)) ?? 90
        recommendedSets = (try? c.decode(Int.self, forKey: .recommendedSets)) ?? 3
        recommendedReps = (try? c.decode(String.self, forKey: .recommendedReps)) ?? "8-12"
        configurationFields = (try? c.decode([String].self, forKey: .configurationFields)) ?? []
        recommendedConfigBySet = (try? c.decode([[String: String]].self, forKey: .recommendedConfigBySet)) ?? []
        cardioPrescription = try c.decodeIfPresent(CardioPrescription.self, forKey: .cardioPrescription)
        originSlotId = try c.decodeIfPresent(UUID.self, forKey: .originSlotId)
        if originSlotId == nil, let tid = try? c.decode(UUID.self, forKey: .templateSlotId), isSlotPlaceholder {
            originSlotId = tid
        }
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
        if let cardioPrescription { try c.encode(cardioPrescription, forKey: .cardioPrescription) }
        if isSlotPlaceholder { try c.encode(true, forKey: .isSlotPlaceholder) }
        if let tid = templateSlotId { try c.encode(tid, forKey: .templateSlotId) }
        let label = slotLabel
        if !label.isEmpty { try c.encode(label, forKey: .slotLabel) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, resolution, exercise, defaultRestTime, recommendedSets, recommendedReps
        case configurationFields, recommendedConfigBySet, cardioPrescription
        case isSlotPlaceholder, templateSlotId, slotLabel, originSlotId
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
    var cardioPrescription: CardioPrescription?

    init(
        id: UUID = UUID(),
        label: String,
        targetedMuscles: [MuscleGroup],
        exerciseRole: ExerciseRole? = nil,
        movementPattern: MovementPattern? = nil,
        defaultExerciseId: UUID? = nil,
        defaultRestTime: Int = 90,
        recommendedSets: Int = 3,
        recommendedReps: String = "8-12",
        cardioPrescription: CardioPrescription? = nil
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
        self.cardioPrescription = cardioPrescription
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
        cardioPrescription = try c.decodeIfPresent(CardioPrescription.self, forKey: .cardioPrescription)
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
        if let cardioPrescription { try c.encode(cardioPrescription, forKey: .cardioPrescription) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, targetedMuscles, exerciseRole, movementPattern, defaultExerciseId
        case defaultRestTime, recommendedSets, recommendedReps, cardioPrescription
    }
}

extension TemplateSlot {
    func asSlotBlueprint() -> SlotBlueprint {
        SlotBlueprint(
            id: id,
            label: label,
            targetedMuscles: targetedMuscles,
            exerciseRole: exerciseRole,
            movementPattern: movementPattern,
            defaultExerciseId: defaultExerciseId,
            defaultRestTime: defaultRestTime,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            cardioPrescription: cardioPrescription
        )
    }
}

extension SlotBlueprint {
    func asTemplateSlot() -> TemplateSlot {
        TemplateSlot(
            id: id,
            label: label,
            targetedMuscles: targetedMuscles,
            exerciseRole: exerciseRole,
            movementPattern: movementPattern,
            defaultExerciseId: defaultExerciseId,
            defaultRestTime: defaultRestTime,
            recommendedSets: recommendedSets,
            recommendedReps: recommendedReps,
            cardioPrescription: cardioPrescription
        )
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var slots: [TemplateSlot]
}

struct Workout: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var exercises: [WorkoutExercise]
    /// Workout exercise row id → template slot id (only for workouts built from a slot template).
    var templateSlotIdByWorkoutExerciseId: [UUID: UUID]
    /// Strength by default; auto-derived when saving if left at default.
    var workoutKind: WorkoutKind

    init(id: UUID, name: String, exercises: [WorkoutExercise], templateSlotIdByWorkoutExerciseId: [UUID: UUID] = [:], workoutKind: WorkoutKind = .strength) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.templateSlotIdByWorkoutExerciseId = templateSlotIdByWorkoutExerciseId
        self.workoutKind = workoutKind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        exercises = try c.decode([WorkoutExercise].self, forKey: .exercises)
        templateSlotIdByWorkoutExerciseId = (try? c.decodeIfPresent([UUID: UUID].self, forKey: .templateSlotIdByWorkoutExerciseId)) ?? [:]
        if let raw = try c.decodeIfPresent(String.self, forKey: .workoutKind),
           let kind = WorkoutKind(rawValue: raw) {
            workoutKind = kind
        } else {
            workoutKind = .strength
        }
        normalizeTemplateSlotBindingsAfterDecoding()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(exercises, forKey: .exercises)
        if !templateSlotIdByWorkoutExerciseId.isEmpty {
            try c.encode(templateSlotIdByWorkoutExerciseId, forKey: .templateSlotIdByWorkoutExerciseId)
        }
        if workoutKind != .strength {
            try c.encode(workoutKind.rawValue, forKey: .workoutKind)
        }
    }

    /// Merges legacy per-row `originSlotId` / unresolved `templateSlotId` into the workout-level map, then clears row-level legacy fields.
    mutating func normalizeTemplateSlotBindingsAfterDecoding() {
        var map = templateSlotIdByWorkoutExerciseId
        for we in exercises {
            if map[we.id] != nil { continue }
            if let o = we.originSlotId {
                map[we.id] = o
            } else if let t = we.templateSlotId {
                map[we.id] = t
            }
        }
        templateSlotIdByWorkoutExerciseId = map
        exercises = exercises.map { var w = $0; w.originSlotId = nil; return w }
    }

    func templateSlotId(forWorkoutExerciseRow rowId: UUID) -> UUID? {
        templateSlotIdByWorkoutExerciseId[rowId]
    }

    /// True when the library workout uses slot blueprints (session copy resolves defaults / open picks).
    var hasFlexibleSlots: Bool {
        exercises.contains { we in
            if case .flexible = we.resolution { return true }
            return false
        }
    }

    /// True when at least one slot has no default exercise (user picks each session).
    var hasOpenSlots: Bool {
        exercises.contains { $0.isOpenSlot }
    }

    /// Short summary for library lists, e.g. "4 exercises" or "4 exercises · 1 open".
    var listDetailSubtitle: String {
        if exercises.isEmpty { return "Empty workout" }
        let n = exercises.count
        let nOpen = exercises.filter(\.isOpenSlot).count
        let exerciseWord = n == 1 ? "exercise" : "exercises"
        if nOpen == 0 { return "\(n) \(exerciseWord)" }
        return "\(n) \(exerciseWord) · \(nOpen) open"
    }

    /// Converts a legacy slot template into a single library workout (flexible blueprints, including `defaultExerciseId` when set).
    static func fromLegacyTemplate(_ template: WorkoutTemplate) -> Workout {
        var exercises: [WorkoutExercise] = []
        var slotByRow: [UUID: UUID] = [:]
        for slot in template.slots {
            let weId = UUID()
            let blueprint = slot.asSlotBlueprint()
            slotByRow[weId] = blueprint.id
            exercises.append(
                WorkoutExercise(
                    id: weId,
                    resolution: .flexible(blueprint),
                    defaultRestTime: slot.defaultRestTime,
                    recommendedSets: slot.recommendedSets,
                    recommendedReps: slot.recommendedReps,
                    cardioPrescription: slot.cardioPrescription
                )
            )
        }
        return Workout(
            id: template.id,
            name: template.name,
            exercises: exercises,
            templateSlotIdByWorkoutExerciseId: slotByRow
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, exercises, templateSlotIdByWorkoutExerciseId, workoutKind
    }
}

/// One step in a drop set after the top weight (same set, one rest after the full sequence).
struct DropSetSegment: Codable, Equatable, Hashable {
    var weight: Double
    var reps: Int
}

/// Classification for a logged set (extends legacy warm-up flag).
enum ExerciseSetType: String, Codable, CaseIterable, Equatable, Hashable {
    case working
    case warmup
    case dropSet
    case failure
    case timed
    case amrap
    case intervalWork
    case intervalRest
    case steadyState

    /// Short label for pickers and chips.
    var logPickerLabel: String {
        switch self {
        case .working: return "Working"
        case .warmup: return "Warm-up"
        case .dropSet: return "Drop set"
        case .failure: return "Failure"
        case .timed: return "Timed hold"
        case .amrap: return "AMRAP"
        case .intervalWork: return "Interval"
        case .intervalRest: return "Rest"
        case .steadyState: return "Steady"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = ExerciseSetType(rawValue: raw) ?? .working
    }
}

struct LoggedSet: Identifiable, Codable {
    let id: UUID
    var weight: Double
    var reps: Int
    var restTime: Int
    var timestamp: Date
    /// Primary set classification; `isWarmup` mirrors `.warmup` for compatibility.
    var setType: ExerciseSetType = .working
    /// Option id (uuidString) -> chosen value. Only present when exercise has configuration options.
    var configuration: [String: String]
    /// Lighter loads after `weight` × `reps`, in order (optional).
    var dropSegments: [DropSetSegment]
    /// Rate of perceived exertion (optional), typically ~6–10.
    var rpe: Double?
    /// Cardio metrics overlay; when set this row is treated as a cardio log entry.
    var cardioMetrics: CardioMetrics?

    /// Legacy warm-up flag; encoded for older payloads and toggles in the full log sheet.
    var isWarmup: Bool {
        get { setType == .warmup }
        set {
            if newValue {
                setType = .warmup
            } else if setType == .warmup {
                setType = .working
            }
        }
    }

    init(
        id: UUID,
        weight: Double,
        reps: Int,
        restTime: Int,
        timestamp: Date,
        setType: ExerciseSetType = .working,
        configuration: [String: String] = [:],
        dropSegments: [DropSetSegment] = [],
        rpe: Double? = nil,
        cardioMetrics: CardioMetrics? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.restTime = restTime
        self.timestamp = timestamp
        self.setType = setType
        self.configuration = configuration
        self.dropSegments = dropSegments
        self.rpe = rpe
        self.cardioMetrics = cardioMetrics
    }

    /// Convenience initializer matching the legacy `isWarmup` parameter.
    init(id: UUID, weight: Double, reps: Int, restTime: Int, timestamp: Date, isWarmup: Bool = false, configuration: [String: String] = [:], dropSegments: [DropSetSegment] = [], rpe: Double? = nil, cardioMetrics: CardioMetrics? = nil) {
        self.init(
            id: id,
            weight: weight,
            reps: reps,
            restTime: restTime,
            timestamp: timestamp,
            setType: isWarmup ? .warmup : .working,
            configuration: configuration,
            dropSegments: dropSegments,
            rpe: rpe,
            cardioMetrics: cardioMetrics
        )
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        weight = try c.decode(Double.self, forKey: .weight)
        reps = try c.decode(Int.self, forKey: .reps)
        restTime = try c.decode(Int.self, forKey: .restTime)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        configuration = (try? c.decode([String: String].self, forKey: .configuration)) ?? [:]
        dropSegments = (try? c.decode([DropSetSegment].self, forKey: .dropSegments)) ?? []
        rpe = try c.decodeIfPresent(Double.self, forKey: .rpe)
        cardioMetrics = try c.decodeIfPresent(CardioMetrics.self, forKey: .cardioMetrics)

        if let decoded = try c.decodeIfPresent(ExerciseSetType.self, forKey: .setType) {
            setType = decoded
        } else {
            let legacyWarm = (try? c.decode(Bool.self, forKey: .isWarmup)) ?? false
            setType = legacyWarm ? .warmup : .working
        }
        if setType == .working, !dropSegments.isEmpty {
            setType = .dropSet
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(weight, forKey: .weight)
        try c.encode(reps, forKey: .reps)
        try c.encode(restTime, forKey: .restTime)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(setType, forKey: .setType)
        try c.encode(isWarmup, forKey: .isWarmup)
        if !configuration.isEmpty { try c.encode(configuration, forKey: .configuration) }
        if !dropSegments.isEmpty { try c.encode(dropSegments, forKey: .dropSegments) }
        if let rpe { try c.encode(rpe, forKey: .rpe) }
        if let cardioMetrics { try c.encode(cardioMetrics, forKey: .cardioMetrics) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, weight, reps, restTime, timestamp, isWarmup, setType, configuration, dropSegments, rpe, cardioMetrics
    }
}

struct ExerciseLog: Identifiable, Codable {
    let id: UUID
    var workoutExercise: WorkoutExercise
    var loggedSets: [LoggedSet]
    /// Freeform notes for this exercise during the session.
    var notes: String
    /// When set, inline / full log rest prefill uses this instead of history or `WorkoutExercise.defaultRestTime`. Session-only (not written back to the library workout).
    var sessionRestOverrideSeconds: Int?

    init(
        id: UUID,
        workoutExercise: WorkoutExercise,
        loggedSets: [LoggedSet],
        notes: String = "",
        sessionRestOverrideSeconds: Int? = nil
    ) {
        self.id = id
        self.workoutExercise = workoutExercise
        self.loggedSets = loggedSets
        self.notes = notes
        self.sessionRestOverrideSeconds = sessionRestOverrideSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        workoutExercise = try c.decode(WorkoutExercise.self, forKey: .workoutExercise)
        loggedSets = try c.decode([LoggedSet].self, forKey: .loggedSets)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sessionRestOverrideSeconds = try c.decodeIfPresent(Int.self, forKey: .sessionRestOverrideSeconds)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(workoutExercise, forKey: .workoutExercise)
        try c.encode(loggedSets, forKey: .loggedSets)
        if !notes.isEmpty { try c.encode(notes, forKey: .notes) }
        if let sessionRestOverrideSeconds { try c.encode(sessionRestOverrideSeconds, forKey: .sessionRestOverrideSeconds) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, workoutExercise, loggedSets, notes, sessionRestOverrideSeconds
    }
}

extension ExerciseLog {
    /// Sets that advance progress toward `recommendedSets`.
    var workingSetCount: Int {
        loggedSets.filter(\.countsTowardRecommendedSets).count
    }

    var warmupSetCount: Int {
        loggedSets.filter { $0.setType == .warmup }.count
    }

    /// True when the prescribed work sets are all in.
    var meetsRecommendedSets: Bool {
        workingSetCount >= max(1, workoutExercise.recommendedSets)
    }
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
    /// Notes for the whole workout (optional).
    var sessionNotes: String = ""
    var isCompleted: Bool { endTime != nil }

    init(
        id: UUID,
        workout: Workout,
        startTime: Date,
        endTime: Date? = nil,
        exerciseLogs: [ExerciseLog],
        activeExerciseIds: [UUID] = [],
        completedExerciseIds: [UUID] = [],
        sessionPlanOrigin: WorkoutPlanRef? = nil,
        sessionNotes: String = ""
    ) {
        self.id = id
        self.workout = workout
        self.startTime = startTime
        self.endTime = endTime
        self.exerciseLogs = exerciseLogs
        self.activeExerciseIds = activeExerciseIds
        self.completedExerciseIds = completedExerciseIds
        self.sessionPlanOrigin = sessionPlanOrigin
        self.sessionNotes = sessionNotes
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
        sessionNotes = try c.decodeIfPresent(String.self, forKey: .sessionNotes) ?? ""
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
        if !sessionNotes.isEmpty { try c.encode(sessionNotes, forKey: .sessionNotes) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, workout, startTime, endTime, exerciseLogs, activeExerciseIds, completedExerciseIds, sessionPlanOrigin, sessionNotes
    }

    /// New in-progress session with the same workout snapshot, exercise rows, logged sets, and active/completed exercise state as `completed`.
    static func resumingFromCompletedSession(_ completed: WorkoutSession) -> WorkoutSession {
        let copiedLogs: [ExerciseLog] = completed.exerciseLogs.map { log in
            let newSets = log.loggedSets.map { s in
                LoggedSet(
                    id: UUID(),
                    weight: s.weight,
                    reps: s.reps,
                    restTime: s.restTime,
                    timestamp: s.timestamp,
                    setType: s.setType,
                    configuration: s.configuration,
                    dropSegments: s.dropSegments,
                    rpe: s.rpe,
                    cardioMetrics: s.cardioMetrics
                )
            }
            return ExerciseLog(
                id: UUID(),
                workoutExercise: log.workoutExercise,
                loggedSets: newSets,
                notes: log.notes,
                sessionRestOverrideSeconds: log.sessionRestOverrideSeconds
            )
        }
        var active = completed.activeExerciseIds
        if active.isEmpty {
            if let exId = copiedLogs.first(where: { !$0.workoutExercise.isSlotPlaceholder })?.workoutExercise.exerciseId {
                active = [exId]
            } else if let exId = copiedLogs.first?.workoutExercise.exerciseId {
                active = [exId]
            }
        }
        return WorkoutSession(
            id: UUID(),
            workout: completed.workout,
            startTime: Date(),
            endTime: nil,
            exerciseLogs: copiedLogs,
            activeExerciseIds: active,
            completedExerciseIds: completed.completedExerciseIds,
            sessionPlanOrigin: completed.sessionPlanOrigin
        )
    }
}

extension LoggedSet {
    /// True when this set carries cardio metrics (interval or steady-state segment).
    var isCardioEntry: Bool { cardioMetrics != nil }

    /// Non–warm-up sets with reps (includes failure). Excludes timed holds and cardio from volume-style totals.
    var countsTowardVolumeTotals: Bool {
        guard cardioMetrics == nil else { return false }
        return reps > 0 && setType != .warmup && setType != .timed
    }

    /// Sets that can establish load / est. 1RM / volume PRs (excludes warm-up, timed, failure, and cardio sets).
    var countsTowardLoadPRMetrics: Bool {
        guard cardioMetrics == nil else { return false }
        return reps > 0 && setType != .warmup && setType != .timed && setType != .failure
    }

    /// Cardio sets that count toward weekly cardio volume summaries.
    var countsTowardCardioTotals: Bool {
        cardioMetrics != nil && setType != .warmup && setType != .intervalRest
    }

    /// Progress against `recommendedSets`. Warm-ups are preparation, not prescribed work.
    ///
    /// Deliberately diverges from `countsTowardVolumeTotals`, which also excludes `.timed`:
    /// a plank is a prescribed set that contributes no tonnage. Keep the two separate.
    var countsTowardRecommendedSets: Bool {
        cardioMetrics == nil && setType != .warmup
    }

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

    /// Non-working set badge for session/history rows (nil when `.working`).
    var setTypeBadgeLabel: String? {
        switch setType {
        case .working: return nil
        case .warmup: return "Warm-up"
        case .dropSet: return "Drop"
        case .failure: return "Failure"
        case .timed: return "Timed"
        case .amrap: return "AMRAP"
        case .intervalWork: return "Interval"
        case .intervalRest: return "Rest"
        case .steadyState: return "Steady"
        }
    }

    /// Single-line summary for cardio sets (duration, distance, HR, calories).
    var cardioDisplaySummary: String {
        guard let metrics = cardioMetrics else { return weightRepsDisplaySummary() }
        var parts: [String] = []
        if let sec = metrics.durationSec, sec > 0 {
            parts.append(CardioMetricsCalculator.formatDuration(seconds: sec))
        }
        if let meters = metrics.distanceM, meters > 0 {
            parts.append(CardioMetricsCalculator.formatDistance(meters: meters))
        }
        if let pace = metrics.avgPaceSecPerKm, pace > 0 {
            parts.append(CardioMetricsCalculator.formatPace(secPerKm: pace))
        }
        if let hr = metrics.avgHeartRate, hr > 0 {
            parts.append("\(hr) bpm")
        }
        if let cal = metrics.calories, cal > 0 {
            parts.append("\(Int(cal.rounded())) kcal")
        }
        if parts.isEmpty { return setTypeBadgeLabel ?? "Cardio" }
        return parts.joined(separator: " · ")
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

