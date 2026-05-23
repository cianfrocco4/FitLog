//
//  CardioModels.swift
//  FitLog
//
//  Domain types for cardio exercise metadata, prescriptions, and logged metrics.
//

import Foundation

// MARK: - Modality

/// Whether an exercise or workout row is strength, cardio, or supports both logging styles.
enum ExerciseModality: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case strength
    case cardio
    case hybrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .hybrid: return "Hybrid"
        }
    }
}

/// Persisted workout classification for library filtering and scheduling badges.
enum WorkoutKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case strength
    case cardio
    case hybrid

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .hybrid: return "Hybrid"
        }
    }

    /// Derives the persisted kind from workout rows and the global exercise library.
    static func derived(from workout: Workout, exercises: [Exercise]) -> WorkoutKind {
        let byId = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        var sawStrength = false
        var sawCardio = false

        for row in workout.exercises {
            guard let exerciseId = row.exerciseId, let exercise = byId[exerciseId] else {
                if row.cardioPrescription != nil {
                    sawCardio = true
                } else {
                    sawStrength = true
                }
                continue
            }
            switch exercise.modality {
            case .strength:
                sawStrength = true
            case .cardio:
                sawCardio = true
            case .hybrid:
                sawStrength = true
                sawCardio = true
            }
            if row.cardioPrescription != nil { sawCardio = true }
        }

        switch (sawStrength, sawCardio) {
        case (true, true): return .hybrid
        case (false, true): return .cardio
        default: return .strength
        }
    }
}

// MARK: - Exercise metadata

enum CardioActivityKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case run
    case walk
    case cycle
    case row
    case swim
    case elliptical
    case stairClimber
    case jumpRope
    case hiit
    case generic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .run: return "Running"
        case .walk: return "Walking"
        case .cycle: return "Cycling"
        case .row: return "Rowing"
        case .swim: return "Swimming"
        case .elliptical: return "Elliptical"
        case .stairClimber: return "Stair Climber"
        case .jumpRope: return "Jump Rope"
        case .hiit: return "HIIT"
        case .generic: return "Cardio"
        }
    }
}

enum CardioPrimaryMetric: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case time
    case distance
    case calories
    case strokes
    case steps
    case laps

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .time: return "Time"
        case .distance: return "Distance"
        case .calories: return "Calories"
        case .strokes: return "Strokes"
        case .steps: return "Steps"
        case .laps: return "Laps"
        }
    }
}

enum CardioEquipment: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case treadmill
    case outdoor
    case bike
    case rower
    case pool
    case machine
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .treadmill: return "Treadmill"
        case .outdoor: return "Outdoor"
        case .bike: return "Bike"
        case .rower: return "Rower"
        case .pool: return "Pool"
        case .machine: return "Machine"
        case .none: return "None"
        }
    }
}

enum CardioIntensityZone: Int, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case zone1 = 1
    case zone2 = 2
    case zone3 = 3
    case zone4 = 4
    case zone5 = 5

    var id: Int { rawValue }

    var displayName: String { "Zone \(rawValue)" }
}

/// Cardio-specific library metadata stored on `Exercise` when `modality != .strength`.
struct CardioExerciseMetadata: Codable, Equatable, Hashable, Sendable {
    var activityKind: CardioActivityKind
    var primaryMetric: CardioPrimaryMetric
    var equipment: CardioEquipment
    /// Estimated metabolic equivalent; used for calorie estimates when HR is unavailable.
    var estimatedMETs: Double?
    var supportsIntervals: Bool
    /// HealthKit `HKWorkoutActivityType` raw value string for export mapping (no HealthKit import here).
    var hkActivityTypeRaw: String?

    init(
        activityKind: CardioActivityKind = .generic,
        primaryMetric: CardioPrimaryMetric = .time,
        equipment: CardioEquipment = .none,
        estimatedMETs: Double? = nil,
        supportsIntervals: Bool = true,
        hkActivityTypeRaw: String? = nil
    ) {
        self.activityKind = activityKind
        self.primaryMetric = primaryMetric
        self.equipment = equipment
        self.estimatedMETs = estimatedMETs
        self.supportsIntervals = supportsIntervals
        self.hkActivityTypeRaw = hkActivityTypeRaw
    }
}

// MARK: - Prescription

enum CardioPrescriptionKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case steadyState
    case intervals
    case circuit
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steadyState: return "Steady State"
        case .intervals: return "Intervals"
        case .circuit: return "Circuit"
        case .custom: return "Custom"
        }
    }
}

struct CardioIntervalSpec: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    /// Work duration in seconds when `workDistanceM` is nil.
    var workDurationSec: Int?
    /// Work distance in meters when set instead of duration.
    var workDistanceM: Double?
    var restDurationSec: Int?
    var targetPaceSecPerKm: Int?
    var targetHeartRate: Int?
    var targetZone: CardioIntensityZone?
    var repeatCount: Int

    init(
        id: UUID = UUID(),
        workDurationSec: Int? = nil,
        workDistanceM: Double? = nil,
        restDurationSec: Int? = nil,
        targetPaceSecPerKm: Int? = nil,
        targetHeartRate: Int? = nil,
        targetZone: CardioIntensityZone? = nil,
        repeatCount: Int = 1
    ) {
        self.id = id
        self.workDurationSec = workDurationSec
        self.workDistanceM = workDistanceM
        self.restDurationSec = restDurationSec
        self.targetPaceSecPerKm = targetPaceSecPerKm
        self.targetHeartRate = targetHeartRate
        self.targetZone = targetZone
        self.repeatCount = max(1, repeatCount)
    }
}

struct CardioPrescription: Codable, Equatable, Hashable, Sendable {
    var kind: CardioPrescriptionKind
    var targetDurationSec: Int?
    var targetDistanceM: Double?
    var targetPaceSecPerKm: Int?
    var targetZone: CardioIntensityZone?
    var intervals: [CardioIntervalSpec]
    var notes: String?

    init(
        kind: CardioPrescriptionKind = .steadyState,
        targetDurationSec: Int? = nil,
        targetDistanceM: Double? = nil,
        targetPaceSecPerKm: Int? = nil,
        targetZone: CardioIntensityZone? = nil,
        intervals: [CardioIntervalSpec] = [],
        notes: String? = nil
    ) {
        self.kind = kind
        self.targetDurationSec = targetDurationSec
        self.targetDistanceM = targetDistanceM
        self.targetPaceSecPerKm = targetPaceSecPerKm
        self.targetZone = targetZone
        self.intervals = intervals
        self.notes = notes
    }
}

// MARK: - Logged metrics

enum CardioMetricsSource: String, Codable, CaseIterable, Hashable, Sendable {
    case manual
    case timer
    case healthKit
}

/// Optional overlay on `LoggedSet` for cardio intervals and steady-state segments.
struct CardioMetrics: Codable, Equatable, Hashable, Sendable {
    var durationSec: Int?
    var distanceM: Double?
    var avgPaceSecPerKm: Int?
    var avgHeartRate: Int?
    var maxHeartRate: Int?
    var calories: Double?
    var incline: Double?
    var cadence: Int?
    var strokes: Int?
    var elevationGainM: Double?
    var source: CardioMetricsSource

    init(
        durationSec: Int? = nil,
        distanceM: Double? = nil,
        avgPaceSecPerKm: Int? = nil,
        avgHeartRate: Int? = nil,
        maxHeartRate: Int? = nil,
        calories: Double? = nil,
        incline: Double? = nil,
        cadence: Int? = nil,
        strokes: Int? = nil,
        elevationGainM: Double? = nil,
        source: CardioMetricsSource = .manual
    ) {
        self.durationSec = durationSec
        self.distanceM = distanceM
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.maxHeartRate = maxHeartRate
        self.avgHeartRate = avgHeartRate
        self.calories = calories
        self.incline = incline
        self.cadence = cadence
        self.strokes = strokes
        self.elevationGainM = elevationGainM
        self.source = source
    }

    /// Computes pace from duration and distance when not explicitly set.
    var resolvedPaceSecPerKm: Int? {
        if let avgPaceSecPerKm { return avgPaceSecPerKm }
        guard let durationSec, let distanceM, distanceM > 0 else { return nil }
        let km = distanceM / 1000.0
        guard km > 0 else { return nil }
        return Int(Double(durationSec) / km)
    }
}
