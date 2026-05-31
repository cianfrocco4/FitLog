//
//  DynamicProgramGenerationModels.swift
//  FitLog
//
//  Wizard input for dynamic program AI generation (reuses split-builder structured fields).
//

import Foundation

/// One row in the “periodized blocks” step (or a single row for simple mode).
struct DynamicBlockGenerationSpec: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var focus: BlockFocus
    var durationWeeks: Int
    var progressionStrategy: ProgressionStrategy
    var volumeMultiplier: Double
    var isDeloadBlock: Bool
    /// Per-block cardio overrides (nil = inherit program defaults).
    var cardioGoal: CardioProgramGoal?
    var cardioPreference: CardioProgramPreference?
    var cardioDedicatedDayCount: Int?
    var cardioFinisherDurationMinutes: Int?
    var cardioFinisherZone: CardioIntensityZone?
    var cardioWeeklyProgressionMinutes: Int?

    init(
        id: UUID = UUID(),
        title: String,
        focus: BlockFocus,
        durationWeeks: Int = 4,
        progressionStrategy: ProgressionStrategy = .doubleProgression,
        volumeMultiplier: Double = 1.0,
        isDeloadBlock: Bool = false,
        cardioGoal: CardioProgramGoal? = nil,
        cardioPreference: CardioProgramPreference? = nil,
        cardioDedicatedDayCount: Int? = nil,
        cardioFinisherDurationMinutes: Int? = nil,
        cardioFinisherZone: CardioIntensityZone? = nil,
        cardioWeeklyProgressionMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.focus = focus
        self.durationWeeks = max(1, durationWeeks)
        self.progressionStrategy = progressionStrategy
        self.volumeMultiplier = volumeMultiplier
        self.isDeloadBlock = isDeloadBlock
        self.cardioGoal = cardioGoal
        self.cardioPreference = cardioPreference
        self.cardioDedicatedDayCount = cardioDedicatedDayCount
        self.cardioFinisherDurationMinutes = cardioFinisherDurationMinutes
        self.cardioFinisherZone = cardioFinisherZone
        self.cardioWeeklyProgressionMinutes = cardioWeeklyProgressionMinutes
    }
}

/// Full request for `AIService.generateDynamicProgram`.
struct DynamicProgramGenerationRequest: Equatable, Sendable {
    /// Same payload as the legacy AI split wizard.
    var splitInput: WorkoutSplitBuilderStructuredInput
    var programName: String
    /// When false, `blockSpecs` should contain exactly one block definition.
    var isPeriodized: Bool
    var blockSpecs: [DynamicBlockGenerationSpec]
    var busyDayPolicy: BusyDayPolicy

    init(
        splitInput: WorkoutSplitBuilderStructuredInput,
        programName: String,
        isPeriodized: Bool,
        blockSpecs: [DynamicBlockGenerationSpec],
        busyDayPolicy: BusyDayPolicy = .skip
    ) {
        self.splitInput = splitInput
        self.programName = programName
        self.isPeriodized = isPeriodized
        self.blockSpecs = blockSpecs
        self.busyDayPolicy = busyDayPolicy
    }

    /// Default for a simple single-block program (matches common AI split defaults).
    static func simpleDefault(programName: String = "My training program") -> DynamicProgramGenerationRequest {
        let input = WorkoutSplitBuilderStructuredInput(
            primaryGoal: "General fitness & health",
            equipment: "Full gym (machines + free weights)",
            splitPreference: "No preference — you decide",
            experienceLevel: "Intermediate",
            sessionsPerWeek: 3,
            preferredWeekdays: [],
            limitationsNotes: "",
            additionalNotes: "",
            sessionDurationMinutes: nil,
            intensityStyle: "Balanced (mix of heavy and moderate)",
            progressionStyle: "No preference — you decide",
            priorityMusclesOrLiftsNotes: "",
            recoveryContextNotes: "",
            deloadPreference: "Not specified",
            variationMode: "Balanced variation",
            desiredWorkoutRotationLength: nil,
            variationNotes: "",
            adjustmentInstruction: nil
        )
        let block = DynamicBlockGenerationSpec(
            title: "Block 1",
            focus: BlockFocus(kind: .general, emphasisLabel: ""),
            durationWeeks: 4,
            progressionStrategy: input.resolvedProgressionStrategy()
        )
        return DynamicProgramGenerationRequest(
            splitInput: input,
            programName: programName,
            isPeriodized: false,
            blockSpecs: [block],
            busyDayPolicy: .skip
        )
    }
}

extension WorkoutSplitBuilderStructuredInput {
    /// Maps split wizard progression copy to engine enum (best-effort).
    func resolvedProgressionStrategy() -> ProgressionStrategy {
        let raw = progressionStyle.lowercased()
        if raw.contains("linear") { return .linear }
        if raw.contains("double") { return .doubleProgression }
        if raw.contains("autoreg") { return .autoregulated }
        if raw.contains("undulat") { return .undulating }
        return .doubleProgression
    }
}

// MARK: - Preferences persistence (UserDefaults envelope)

/// Codable snapshot of one block row in the program builder wizard.
struct PersistedDynamicBlockSpec: Codable, Equatable, Sendable {
    var id: UUID
    var title: String
    var focusKindRaw: String
    var emphasisLabel: String
    var durationWeeks: Int
    var progressionStrategyRaw: String
    var volumeMultiplier: Double
    var isDeloadBlock: Bool
    var cardioGoalRaw: String?
    var cardioPreferenceRaw: String?
    var cardioDedicatedDayCount: Int?
    var cardioFinisherDurationMinutes: Int?
    var cardioFinisherZoneRaw: Int?
    var cardioWeeklyProgressionMinutes: Int?
}

extension DynamicBlockGenerationSpec {
    init(persisted: PersistedDynamicBlockSpec) {
        let kind = BlockFocusKind(rawValue: persisted.focusKindRaw) ?? .general
        let progression = ProgressionStrategy(rawValue: persisted.progressionStrategyRaw) ?? .doubleProgression
        self.init(
            id: persisted.id,
            title: persisted.title,
            focus: BlockFocus(kind: kind, emphasisLabel: persisted.emphasisLabel),
            durationWeeks: persisted.durationWeeks,
            progressionStrategy: progression,
            volumeMultiplier: persisted.volumeMultiplier,
            isDeloadBlock: persisted.isDeloadBlock,
            cardioGoal: persisted.cardioGoalRaw.flatMap { CardioProgramGoal(rawValue: $0) },
            cardioPreference: persisted.cardioPreferenceRaw.flatMap { CardioProgramPreference(rawValue: $0) },
            cardioDedicatedDayCount: persisted.cardioDedicatedDayCount,
            cardioFinisherDurationMinutes: persisted.cardioFinisherDurationMinutes,
            cardioFinisherZone: persisted.cardioFinisherZoneRaw.flatMap { CardioIntensityZone(rawValue: $0) },
            cardioWeeklyProgressionMinutes: persisted.cardioWeeklyProgressionMinutes
        )
    }

    func persistedSnapshot() -> PersistedDynamicBlockSpec {
        PersistedDynamicBlockSpec(
            id: id,
            title: title,
            focusKindRaw: focus.kind.rawValue,
            emphasisLabel: focus.emphasisLabel,
            durationWeeks: durationWeeks,
            progressionStrategyRaw: progressionStrategy.rawValue,
            volumeMultiplier: volumeMultiplier,
            isDeloadBlock: isDeloadBlock,
            cardioGoalRaw: cardioGoal?.rawValue,
            cardioPreferenceRaw: cardioPreference?.rawValue,
            cardioDedicatedDayCount: cardioDedicatedDayCount,
            cardioFinisherDurationMinutes: cardioFinisherDurationMinutes,
            cardioFinisherZoneRaw: cardioFinisherZone?.rawValue,
            cardioWeeklyProgressionMinutes: cardioWeeklyProgressionMinutes
        )
    }
}
