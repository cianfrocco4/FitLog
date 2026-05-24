//
//  CardioSessionTimerPersistence.swift
//  FitLog
//
//  Persists in-progress cardio timers across app restarts (mirrors workout timer UserDefaults keys).
//

import Foundation

enum CardioIntervalTimerPhase: String, Codable, Equatable {
    case work
    case rest
}

struct CardioSteadyTimerState: Codable, Equatable {
    var workoutExerciseId: UUID?
    /// Legacy key from builds that keyed timers by list index.
    var legacyExerciseIndex: Int?
    var segmentStartedAt: Date
    var accumulatedSeconds: Int
    var isPaused: Bool

    init(
        workoutExerciseId: UUID,
        segmentStartedAt: Date,
        accumulatedSeconds: Int,
        isPaused: Bool
    ) {
        self.workoutExerciseId = workoutExerciseId
        self.legacyExerciseIndex = nil
        self.segmentStartedAt = segmentStartedAt
        self.accumulatedSeconds = accumulatedSeconds
        self.isPaused = isPaused
    }

    private enum CodingKeys: String, CodingKey {
        case workoutExerciseId
        case exerciseIndex
        case segmentStartedAt
        case accumulatedSeconds
        case isPaused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workoutExerciseId = try container.decodeIfPresent(UUID.self, forKey: .workoutExerciseId)
        legacyExerciseIndex = try container.decodeIfPresent(Int.self, forKey: .exerciseIndex)
        segmentStartedAt = try container.decode(Date.self, forKey: .segmentStartedAt)
        accumulatedSeconds = try container.decode(Int.self, forKey: .accumulatedSeconds)
        isPaused = try container.decode(Bool.self, forKey: .isPaused)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let workoutExerciseId {
            try container.encode(workoutExerciseId, forKey: .workoutExerciseId)
        }
        try container.encode(segmentStartedAt, forKey: .segmentStartedAt)
        try container.encode(accumulatedSeconds, forKey: .accumulatedSeconds)
        try container.encode(isPaused, forKey: .isPaused)
    }

    mutating func resolveWorkoutExerciseId(in session: WorkoutSession) -> Bool {
        if workoutExerciseId != nil { return true }
        guard let legacyExerciseIndex,
              legacyExerciseIndex >= 0,
              legacyExerciseIndex < session.exerciseLogs.count
        else { return false }
        workoutExerciseId = session.exerciseLogs[legacyExerciseIndex].workoutExercise.id
        self.legacyExerciseIndex = nil
        return true
    }

    func resolvedWorkoutExerciseId(in session: WorkoutSession) -> UUID? {
        if let workoutExerciseId { return workoutExerciseId }
        guard let legacyExerciseIndex,
              legacyExerciseIndex >= 0,
              legacyExerciseIndex < session.exerciseLogs.count
        else { return nil }
        return session.exerciseLogs[legacyExerciseIndex].workoutExercise.id
    }
}

struct CardioIntervalTimerState: Codable, Equatable {
    var workoutExerciseId: UUID?
    var legacyExerciseIndex: Int?
    var spec: CardioIntervalSpec
    var phase: CardioIntervalTimerPhase
    var currentRound: Int
    var phaseStartedAt: Date
    var phaseDurationSec: Int
    var isPaused: Bool
    var pausedRemainingSec: Int?
    /// Prevents duplicate auto-complete logging for the same phase.
    var autoCompletedPhaseStart: Date?

    init(
        workoutExerciseId: UUID,
        spec: CardioIntervalSpec,
        phase: CardioIntervalTimerPhase,
        currentRound: Int,
        phaseStartedAt: Date,
        phaseDurationSec: Int,
        isPaused: Bool,
        pausedRemainingSec: Int?
    ) {
        self.workoutExerciseId = workoutExerciseId
        self.legacyExerciseIndex = nil
        self.spec = spec
        self.phase = phase
        self.currentRound = currentRound
        self.phaseStartedAt = phaseStartedAt
        self.phaseDurationSec = phaseDurationSec
        self.isPaused = isPaused
        self.pausedRemainingSec = pausedRemainingSec
        self.autoCompletedPhaseStart = nil
    }

    private enum CodingKeys: String, CodingKey {
        case workoutExerciseId
        case exerciseIndex
        case spec
        case phase
        case currentRound
        case phaseStartedAt
        case phaseDurationSec
        case isPaused
        case pausedRemainingSec
        case autoCompletedPhaseStart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workoutExerciseId = try container.decodeIfPresent(UUID.self, forKey: .workoutExerciseId)
        legacyExerciseIndex = try container.decodeIfPresent(Int.self, forKey: .exerciseIndex)
        spec = try container.decode(CardioIntervalSpec.self, forKey: .spec)
        phase = try container.decode(CardioIntervalTimerPhase.self, forKey: .phase)
        currentRound = try container.decode(Int.self, forKey: .currentRound)
        phaseStartedAt = try container.decode(Date.self, forKey: .phaseStartedAt)
        phaseDurationSec = try container.decode(Int.self, forKey: .phaseDurationSec)
        isPaused = try container.decode(Bool.self, forKey: .isPaused)
        pausedRemainingSec = try container.decodeIfPresent(Int.self, forKey: .pausedRemainingSec)
        autoCompletedPhaseStart = try container.decodeIfPresent(Date.self, forKey: .autoCompletedPhaseStart)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let workoutExerciseId {
            try container.encode(workoutExerciseId, forKey: .workoutExerciseId)
        }
        try container.encode(spec, forKey: .spec)
        try container.encode(phase, forKey: .phase)
        try container.encode(currentRound, forKey: .currentRound)
        try container.encode(phaseStartedAt, forKey: .phaseStartedAt)
        try container.encode(phaseDurationSec, forKey: .phaseDurationSec)
        try container.encode(isPaused, forKey: .isPaused)
        try container.encodeIfPresent(pausedRemainingSec, forKey: .pausedRemainingSec)
        try container.encodeIfPresent(autoCompletedPhaseStart, forKey: .autoCompletedPhaseStart)
    }

    mutating func resolveWorkoutExerciseId(in session: WorkoutSession) -> Bool {
        if workoutExerciseId != nil { return true }
        guard let legacyExerciseIndex,
              legacyExerciseIndex >= 0,
              legacyExerciseIndex < session.exerciseLogs.count
        else { return false }
        workoutExerciseId = session.exerciseLogs[legacyExerciseIndex].workoutExercise.id
        self.legacyExerciseIndex = nil
        return true
    }

    func resolvedWorkoutExerciseId(in session: WorkoutSession) -> UUID? {
        if let workoutExerciseId { return workoutExerciseId }
        guard let legacyExerciseIndex,
              legacyExerciseIndex >= 0,
              legacyExerciseIndex < session.exerciseLogs.count
        else { return nil }
        return session.exerciseLogs[legacyExerciseIndex].workoutExercise.id
    }
}

enum CardioSessionTimerPersistence {
    private static let steadyKey = "activeWorkout.cardioSteadyTimer"
    private static let intervalKey = "activeWorkout.cardioIntervalTimer"

    static func loadSteady() -> CardioSteadyTimerState? {
        load(key: steadyKey)
    }

    static func loadInterval() -> CardioIntervalTimerState? {
        load(key: intervalKey)
    }

    static func save(steady: CardioSteadyTimerState?) {
        save(steady, key: steadyKey)
    }

    static func save(interval: CardioIntervalTimerState?) {
        save(interval, key: intervalKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: steadyKey)
        UserDefaults.standard.removeObject(forKey: intervalKey)
    }

    private static func load<T: Decodable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            #if DEBUG
            print("[CardioSessionTimerPersistence] Failed to encode timer for key \(key)")
            #endif
        }
    }
}
