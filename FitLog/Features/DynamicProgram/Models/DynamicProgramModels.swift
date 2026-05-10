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
    case deload
    case general
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

    init(
        id: UUID = UUID(),
        dayName: String,
        focus: String,
        slots: [SplitBuilderEditableSlot]
    ) {
        self.id = id
        self.dayName = dayName
        self.focus = focus
        self.slots = slots
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

    init(
        id: UUID = UUID(),
        name: String,
        focus: BlockFocus,
        durationWeeks: Int,
        weeklyTemplates: [BlockWeeklyTemplate],
        progressionStrategy: ProgressionStrategy = .doubleProgression,
        isDeloadBlock: Bool = false,
        volumeMultiplier: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.focus = focus
        self.durationWeeks = max(1, durationWeeks)
        self.weeklyTemplates = weeklyTemplates
        self.progressionStrategy = progressionStrategy
        self.isDeloadBlock = isDeloadBlock
        self.volumeMultiplier = volumeMultiplier
    }
}

// MARK: - Full program

struct DynamicProgram: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var createdAt: Date
    var blocks: [ProgramBlock]
    var defaultSessionsPerWeek: Int
    /// Empty = Mon–Fri pool (same as `TrainingProgramState.preferredWeekdays`).
    var preferredWeekdays: [Int]
    var busyDayPolicy: BusyDayPolicy

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        blocks: [ProgramBlock],
        defaultSessionsPerWeek: Int,
        preferredWeekdays: [Int] = [],
        busyDayPolicy: BusyDayPolicy = .skip
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.blocks = blocks
        self.defaultSessionsPerWeek = min(max(1, defaultSessionsPerWeek), 7)
        self.preferredWeekdays = preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        self.busyDayPolicy = busyDayPolicy
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

// MARK: - In-workout progression context (wired in a later task)

struct BlockContext: Equatable, Sendable {
    let blockId: UUID
    let focus: BlockFocus
    let volumeMultiplier: Double
    let progressionStrategy: ProgressionStrategy
    let weekIndexInBlock: Int
    let isDeloadBlock: Bool
}
