//
//  DynamicProgramModels.swift
//  FitLog
//
//  Multi-block periodized programs. A single-block program is the “simple split” shape.
//

import Foundation

// MARK: - Block focus

enum BlockFocusKind: String, Codable, CaseIterable, Sendable {
    case hypertrophy
    case strength
    case power
    case endurance
    case hybrid
    case deload
    case general

    /// Plain-language label for the program wizard (avoid jargon like “hypertrophy”).
    var userFriendlyShortLabel: String {
        switch self {
        case .hypertrophy: return "Build muscle"
        case .strength: return "Get stronger"
        case .power: return "Power & explosiveness"
        case .endurance: return "Endurance & conditioning"
        case .hybrid: return "Strength + cardio"
        case .deload: return "Recovery / easier week"
        case .general: return "Balanced / general fitness"
        }
    }
}

struct BlockFocus: Codable, Equatable, Hashable, Sendable {
    var kind: BlockFocusKind
    /// User-facing sub-label, e.g. “Push emphasis”, “Lower body”.
    var emphasisLabel: String

    init(kind: BlockFocusKind, emphasisLabel: String = "") {
        self.kind = kind
        self.emphasisLabel = emphasisLabel
    }

    var displayTitle: String {
        let base: String
        switch kind {
        case .hypertrophy: base = "Hypertrophy"
        case .strength: base = "Strength"
        case .power: base = "Power"
        case .endurance: base = "Endurance"
        case .hybrid: base = "Strength + Cardio"
        case .deload: base = "Deload"
        case .general: base = "General"
        }
        let trimmed = emphasisLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return base }
        return "\(base) — \(trimmed)"
    }
}

// MARK: - Progression / policy

enum ProgressionStrategy: String, Codable, CaseIterable, Sendable {
    case linear
    case doubleProgression
    case undulating
    case autoregulated
}

enum BusyDayPolicy: String, Codable, CaseIterable, Sendable {
    /// Merge missed work into fewer remaining days in the week (engine hint; UI may refine).
    case compress
    /// Extend current block end, push later blocks forward.
    case shift
    /// Substitute a lighter recovery template on that day.
    case flexDay
    /// Do not auto-adjust; same as legacy skip behavior.
    case skip
}

// MARK: - Weekly template (per rotation slot)

struct BlockWeeklyTemplate: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var dayName: String
    var focus: String
    var slots: [SplitBuilderEditableSlot]
    /// Optional coaching / day-level notes (manual builder).
    var dayNotes: String?

    init(
        id: UUID = UUID(),
        dayName: String,
        focus: String,
        slots: [SplitBuilderEditableSlot],
        dayNotes: String? = nil
    ) {
        self.id = id
        self.dayName = dayName
        self.focus = focus
        self.slots = slots
        self.dayNotes = dayNotes
    }
}

// MARK: - Program block

struct ProgramBlock: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var focus: BlockFocus
    /// Planned length in weeks (may be extended by `DynamicProgramState.blockShiftDays`).
    var durationWeeks: Int
    /// Ordered rotation templates for this block (same semantics as `TrainingProgramState.cycleEntries`).
    var weeklyTemplates: [BlockWeeklyTemplate]
    var progressionStrategy: ProgressionStrategy
    var isDeloadBlock: Bool
    /// 1.0 = normal; use <1 for deload intensity.
    var volumeMultiplier: Double

    /// 1-based week index inside the block treated as deload, if any.
    var deloadWeekNumber: Int?
    /// Block-level coaching / structure notes.
    var notes: String?
    /// Optional warm-up slots applied before main template work (manual builder).
    var warmUpTemplate: [SplitBuilderEditableSlot]?
    /// Optional cooldown / mobility slots (manual builder).
    var cooldownTemplate: [SplitBuilderEditableSlot]?
    /// Cardio goal for this block (nil = inherit program default).
    var cardioGoal: CardioProgramGoal?
    /// Cardio integration style for this block (nil = inherit program default).
    var cardioPreference: CardioProgramPreference?
    var cardioDedicatedDayCount: Int?
    var cardioFinisherDurationMinutes: Int?
    var cardioFinisherZone: CardioIntensityZone?
    var cardioWeeklyProgressionMinutes: Int?
    /// Measurable process goals for this phase (optional; synthesized at read/normalize time when nil).
    var phaseGoal: ProgramPhaseGoal?

    enum CodingKeys: String, CodingKey {
        case id, name, focus, durationWeeks, weeklyTemplates, progressionStrategy, isDeloadBlock, volumeMultiplier
        case deloadWeekNumber, notes, warmUpTemplate, cooldownTemplate
        case cardioGoal, cardioPreference, cardioDedicatedDayCount, cardioFinisherDurationMinutes
        case cardioFinisherZone, cardioWeeklyProgressionMinutes
        case phaseGoal
    }

    init(
        id: UUID = UUID(),
        name: String,
        focus: BlockFocus,
        durationWeeks: Int,
        weeklyTemplates: [BlockWeeklyTemplate],
        progressionStrategy: ProgressionStrategy = .doubleProgression,
        isDeloadBlock: Bool = false,
        volumeMultiplier: Double = 1.0,
        deloadWeekNumber: Int? = nil,
        notes: String? = nil,
        warmUpTemplate: [SplitBuilderEditableSlot]? = nil,
        cooldownTemplate: [SplitBuilderEditableSlot]? = nil,
        cardioGoal: CardioProgramGoal? = nil,
        cardioPreference: CardioProgramPreference? = nil,
        cardioDedicatedDayCount: Int? = nil,
        cardioFinisherDurationMinutes: Int? = nil,
        cardioFinisherZone: CardioIntensityZone? = nil,
        cardioWeeklyProgressionMinutes: Int? = nil,
        phaseGoal: ProgramPhaseGoal? = nil
    ) {
        self.id = id
        self.name = name
        self.focus = focus
        self.durationWeeks = max(1, durationWeeks)
        self.weeklyTemplates = weeklyTemplates
        self.progressionStrategy = progressionStrategy
        self.isDeloadBlock = isDeloadBlock
        self.volumeMultiplier = volumeMultiplier
        self.deloadWeekNumber = deloadWeekNumber
        self.notes = notes
        self.warmUpTemplate = warmUpTemplate
        self.cooldownTemplate = cooldownTemplate
        self.cardioGoal = cardioGoal
        self.cardioPreference = cardioPreference
        self.cardioDedicatedDayCount = cardioDedicatedDayCount
        self.cardioFinisherDurationMinutes = cardioFinisherDurationMinutes
        self.cardioFinisherZone = cardioFinisherZone
        self.cardioWeeklyProgressionMinutes = cardioWeeklyProgressionMinutes
        self.phaseGoal = phaseGoal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        focus = try c.decode(BlockFocus.self, forKey: .focus)
        durationWeeks = try c.decode(Int.self, forKey: .durationWeeks)
        weeklyTemplates = try c.decode([BlockWeeklyTemplate].self, forKey: .weeklyTemplates)
        progressionStrategy = try c.decode(ProgressionStrategy.self, forKey: .progressionStrategy)
        isDeloadBlock = try c.decode(Bool.self, forKey: .isDeloadBlock)
        volumeMultiplier = try c.decode(Double.self, forKey: .volumeMultiplier)
        deloadWeekNumber = try c.decodeIfPresent(Int.self, forKey: .deloadWeekNumber)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        warmUpTemplate = try c.decodeIfPresent([SplitBuilderEditableSlot].self, forKey: .warmUpTemplate)
        cooldownTemplate = try c.decodeIfPresent([SplitBuilderEditableSlot].self, forKey: .cooldownTemplate)
        cardioGoal = try c.decodeIfPresent(CardioProgramGoal.self, forKey: .cardioGoal)
        cardioPreference = try c.decodeIfPresent(CardioProgramPreference.self, forKey: .cardioPreference)
        cardioDedicatedDayCount = try c.decodeIfPresent(Int.self, forKey: .cardioDedicatedDayCount)
        cardioFinisherDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .cardioFinisherDurationMinutes)
        cardioFinisherZone = try c.decodeIfPresent(CardioIntensityZone.self, forKey: .cardioFinisherZone)
        cardioWeeklyProgressionMinutes = try c.decodeIfPresent(Int.self, forKey: .cardioWeeklyProgressionMinutes)
        phaseGoal = try c.decodeIfPresent(ProgramPhaseGoal.self, forKey: .phaseGoal)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(focus, forKey: .focus)
        try c.encode(durationWeeks, forKey: .durationWeeks)
        try c.encode(weeklyTemplates, forKey: .weeklyTemplates)
        try c.encode(progressionStrategy, forKey: .progressionStrategy)
        try c.encode(isDeloadBlock, forKey: .isDeloadBlock)
        try c.encode(volumeMultiplier, forKey: .volumeMultiplier)
        try c.encodeIfPresent(deloadWeekNumber, forKey: .deloadWeekNumber)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(warmUpTemplate, forKey: .warmUpTemplate)
        try c.encodeIfPresent(cooldownTemplate, forKey: .cooldownTemplate)
        try c.encodeIfPresent(cardioGoal, forKey: .cardioGoal)
        try c.encodeIfPresent(cardioPreference, forKey: .cardioPreference)
        try c.encodeIfPresent(cardioDedicatedDayCount, forKey: .cardioDedicatedDayCount)
        try c.encodeIfPresent(cardioFinisherDurationMinutes, forKey: .cardioFinisherDurationMinutes)
        try c.encodeIfPresent(cardioFinisherZone, forKey: .cardioFinisherZone)
        try c.encodeIfPresent(cardioWeeklyProgressionMinutes, forKey: .cardioWeeklyProgressionMinutes)
        try c.encodeIfPresent(phaseGoal, forKey: .phaseGoal)
    }

    /// Resolves effective cardio settings for template generation (block overrides program defaults).
    func resolvedCardioConfiguration(fallback: CardioProgramConfiguration) -> CardioProgramConfiguration {
        var config = fallback
        if let cardioGoal { config.goal = cardioGoal }
        if let cardioPreference { config.preference = cardioPreference }
        if let cardioDedicatedDayCount { config.dedicatedDayCount = cardioDedicatedDayCount }
        if let cardioFinisherDurationMinutes {
            config.finisherDurationMinutes = CardioProgramConfiguration.clampedFinisherMinutes(cardioFinisherDurationMinutes)
        }
        if let cardioFinisherZone { config.finisherZone = cardioFinisherZone }
        if let cardioWeeklyProgressionMinutes { config.weeklyProgressionMinutes = cardioWeeklyProgressionMinutes }
        if specFocusForcesCardio {
            switch focus.kind {
            case .endurance:
                config.preference = .dedicatedDays
                config.goal = .enduranceBuilding
            case .hybrid:
                config.preference = .mixed
            default:
                break
            }
        }
        return config
    }

    private var specFocusForcesCardio: Bool {
        focus.kind == .endurance || focus.kind == .hybrid
    }
}

// MARK: - Full program

struct DynamicProgram: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var blocks: [ProgramBlock]
    var defaultSessionsPerWeek: Int
    /// Empty = Mon–Fri pool (same as `TrainingProgramState.preferredWeekdays`).
    var preferredWeekdays: [Int]
    var busyDayPolicy: BusyDayPolicy
    /// Whether the program was produced via the AI pipeline (vs local presets when AI is not configured).
    var generatedWithAI: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, blocks, defaultSessionsPerWeek, preferredWeekdays, busyDayPolicy, generatedWithAI
    }

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        blocks: [ProgramBlock],
        defaultSessionsPerWeek: Int,
        preferredWeekdays: [Int] = [],
        busyDayPolicy: BusyDayPolicy = .skip,
        generatedWithAI: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.blocks = blocks
        self.defaultSessionsPerWeek = min(max(1, defaultSessionsPerWeek), 7)
        self.preferredWeekdays = preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        self.busyDayPolicy = busyDayPolicy
        self.generatedWithAI = generatedWithAI
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        blocks = try c.decode([ProgramBlock].self, forKey: .blocks)
        defaultSessionsPerWeek = try c.decode(Int.self, forKey: .defaultSessionsPerWeek)
        preferredWeekdays = try c.decode([Int].self, forKey: .preferredWeekdays)
        busyDayPolicy = try c.decode(BusyDayPolicy.self, forKey: .busyDayPolicy)
        generatedWithAI = try c.decodeIfPresent(Bool.self, forKey: .generatedWithAI) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(blocks, forKey: .blocks)
        try c.encode(defaultSessionsPerWeek, forKey: .defaultSessionsPerWeek)
        try c.encode(preferredWeekdays, forKey: .preferredWeekdays)
        try c.encode(busyDayPolicy, forKey: .busyDayPolicy)
        try c.encode(generatedWithAI, forKey: .generatedWithAI)
    }

    /// Sum of planned block weeks (ignores runtime shifts).
    var plannedTotalWeeks: Int {
        blocks.reduce(0) { $0 + $1.durationWeeks }
    }

    /// True when this program behaves like the legacy single-phase split.
    var isSimpleSingleBlock: Bool {
        blocks.count == 1
    }
}

// MARK: - Runtime state (persisted beside SwiftData program row)

struct DynamicProgramState: Codable, Equatable, Sendable {
    var program: DynamicProgram
    /// Start of program timeline (start-of-day semantics with `calendar`).
    var anchorDate: Date
    /// `yyyy-MM-dd` keys the user marked busy / low availability.
    var busyDayKeys: Set<String>
    /// Days a planned session was not completed (detected by adaptation service).
    var missedSessionDayKeys: Set<String>
    /// Extra calendar days added to a block span (e.g. `.shift` policy).
    var blockShiftDays: [UUID: Int]
    var completedBlockIds: Set<UUID>
    /// Same semantics as `TrainingProgramState.skippedCycleTrainingDayKeys` for rotation order.
    var skippedProgramTrainingDayKeys: Set<String>
    /// Maps each `BlockWeeklyTemplate.id` to a library `Workout.id` after templates are materialized (apply / builder).
    var materializedTemplateWorkoutIds: [UUID: UUID]

    init(
        program: DynamicProgram,
        anchorDate: Date,
        busyDayKeys: Set<String> = [],
        missedSessionDayKeys: Set<String> = [],
        blockShiftDays: [UUID: Int] = [:],
        completedBlockIds: Set<UUID> = [],
        skippedProgramTrainingDayKeys: Set<String> = [],
        materializedTemplateWorkoutIds: [UUID: UUID] = [:]
    ) {
        self.program = program
        self.anchorDate = anchorDate
        self.busyDayKeys = busyDayKeys
        self.missedSessionDayKeys = missedSessionDayKeys
        self.blockShiftDays = blockShiftDays
        self.completedBlockIds = completedBlockIds
        self.skippedProgramTrainingDayKeys = skippedProgramTrainingDayKeys
        self.materializedTemplateWorkoutIds = materializedTemplateWorkoutIds
    }
}

// MARK: - Block transition (UI / notifications)

struct BlockTransitionEvent: Equatable, Sendable {
    let previousBlockId: UUID?
    let newBlockId: UUID
    let dayKey: String
}

// MARK: - Resolved template day (pre–library workout materialization)

enum ResolvedProgramTemplateDay: Equatable, Sendable {
    case rest
    case unscheduled
    case training(BlockWeeklyTemplate)
    case flex(BlockWeeklyTemplate)
}

// MARK: - In-workout progression context

struct BlockContext: Equatable, Sendable {
    let blockId: UUID
    let focus: BlockFocus
    let volumeMultiplier: Double
    let progressionStrategy: ProgressionStrategy
    let weekIndexInBlock: Int
    let isDeloadBlock: Bool
    /// Planned block length in weeks (from `ProgramBlock.durationWeeks`).
    let blockDurationWeeks: Int
    /// Optional cardio weekly duration bump (minutes) applied per week in block.
    let cardioWeeklyProgressionMinutes: Int
    let cardioProgressionStrategy: CardioProgressionStrategy

    init(
        blockId: UUID,
        focus: BlockFocus,
        volumeMultiplier: Double,
        progressionStrategy: ProgressionStrategy,
        weekIndexInBlock: Int,
        isDeloadBlock: Bool,
        blockDurationWeeks: Int,
        cardioWeeklyProgressionMinutes: Int = 0,
        cardioProgressionStrategy: CardioProgressionStrategy = .steady
    ) {
        self.blockId = blockId
        self.focus = focus
        self.volumeMultiplier = volumeMultiplier
        self.progressionStrategy = progressionStrategy
        self.weekIndexInBlock = weekIndexInBlock
        self.isDeloadBlock = isDeloadBlock
        self.blockDurationWeeks = blockDurationWeeks
        self.cardioWeeklyProgressionMinutes = cardioWeeklyProgressionMinutes
        self.cardioProgressionStrategy = cardioProgressionStrategy
    }
}
