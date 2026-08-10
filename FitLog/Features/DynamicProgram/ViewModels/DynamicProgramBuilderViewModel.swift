//
//  DynamicProgramBuilderViewModel.swift
//  FitLog
//
//  State for the unified dynamic / periodized program wizard.
//

import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class DynamicProgramBuilderViewModel {
    /// How the user wants training organized over time (plain-language preset).
    enum ProgramStructurePreset: String, CaseIterable, Identifiable, Sendable {
        case singlePhase
        case twoPhases
        case threePhases
        case custom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .singlePhase: return "One continuous phase"
            case .twoPhases: return "Two phases — build, then peak"
            case .threePhases: return "Three phases — build, peak, recover"
            case .custom: return "Custom phases"
            }
        }

        var detail: String {
            switch self {
            case .singlePhase:
                return "Same style of training for the whole program length."
            case .twoPhases:
                return "Start with more muscle-building work, then shift toward heavier strength work."
            case .threePhases:
                return "Build hard, peak strength, then a planned easier week to absorb training."
            case .custom:
                return "Name each phase, pick a goal, and set how many weeks it runs."
            }
        }
    }

    /// Preset total length options for the program wizard.
    enum TotalWeeksTemplate: Int, CaseIterable, Identifiable, Sendable {
        case four = 4
        case six = 6
        case eight = 8
        case ten = 10
        case twelve = 12
        case sixteen = 16
        case custom = 0

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .four: return "4 weeks"
            case .six: return "6 weeks"
            case .eight: return "8 weeks"
            case .ten: return "10 weeks"
            case .twelve: return "12 weeks"
            case .sixteen: return "16 weeks"
            case .custom: return "Custom"
            }
        }
    }

    enum WizardStep: Int, CaseIterable, Identifiable, Hashable {
        case essentials = 0
        case structure = 1
        case reviewAndEdit = 2

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .essentials: return "Essentials"
            case .structure: return "Structure"
            case .reviewAndEdit: return "Review"
            }
        }
    }

    /// Unified builder: AI-assisted generation vs fully manual skeleton.
    enum ProgramBuilderMode: String, CaseIterable, Identifiable, Sendable {
        case aiGenerate
        case manualBuild

        var id: String { rawValue }

        var title: String {
            switch self {
            case .aiGenerate: return "AI generate"
            case .manualBuild: return "Build manually"
            }
        }
    }

    /// Coarse generation pipeline for Guided Coach progress UI (not inferred from block counters).
    enum GenerationStage: Int, Equatable, Sendable {
        case idle = 0
        case connecting = 1
        case designing = 2
        case finalizing = 3
        case ready = 4

        var statusLine: String {
            switch self {
            case .idle: return "Building your program…"
            case .connecting: return "Connecting to AI…"
            case .designing: return "Designing workouts…"
            case .finalizing: return "Finalizing your program…"
            case .ready: return "Ready to review"
            }
        }
    }

    var request: DynamicProgramGenerationRequest
    var wizardStep: WizardStep = .essentials
    /// Progressive disclosure for advanced wizard fields on Structure step.
    var showAdvancedSettings = false
    /// When true, entry screen promotes Quick Start for cold-start users.
    var shouldPromoteQuickStart = false
    /// Persisted via `SplitBuilderPreferencesStore`.
    var builderMode: ProgramBuilderMode = .aiGenerate
    /// For `.sensoryFeedback` when switching builder mode.
    var builderModeChangeCount = 0

    var generatedProgram: DynamicProgram?
    var errorMessage: String?
    var isGenerating = false
    /// True while awaiting proxy `/health` before the first completion.
    var isConnectingToProxy = false
    /// Explicit pipeline stage for progress UI (persists until next run / navigation reset).
    var generationStage: GenerationStage = .idle
    /// Human-readable generation substate (connecting, per-block progress).
    var generationStatusMessage: String?
    /// Current block index completed during multi-phase generation (0 when not started).
    var generationBlockCompleted: Int = 0
    /// Total blocks to generate for the current run.
    var generationBlockTotal: Int = 1
    /// After AI timeout/unavailable, offer built-in preset generation.
    var offersLocalPresetFallback = false
    /// Incremented on successful generation for `.sensoryFeedback` triggers.
    var generationSuccessCount = 0
    /// True when the last successful generation used local presets (no AI client).
    var lastGenerationUsedLocalPresets = false

    /// Start-of-day anchor for `DynamicProgramState` and plan sync.
    var programAnchorDate: Date = Calendar.current.startOfDay(for: Date())
    var isApplying = false
    var applyErrorMessage: String?
    var showApplySavedAlert = false
    var applySavedDetail: String = ""
    /// Incremented when a program is saved to the plan.
    var applySuccessCount = 0

    /// Bumped by every generation, structural mutation, and field commit.
    private var programRevision = 0
    /// Revision the Plan currently reflects; `nil` until the program is hydrated from or saved to Plan.
    private var savedProgramRevision: Int?

    /// True when the on-screen program differs from what the Plan holds, so closing would lose work.
    var hasUnsavedProgramChanges: Bool {
        generatedProgram != nil && savedProgramRevision != programRevision
    }

    private func markProgramChanged() {
        programRevision &+= 1
    }

    private func markProgramSaved() {
        savedProgramRevision = programRevision
    }

    /// Editable weekly templates for **each** program block (source of truth for preview + timeline editing).
    var perBlockEditableDays: [[SplitBuilderEditableDay]] = []
    /// Which program block the main “Templates” form section is editing (0-based).
    var editableBlockIndex: Int = 0
    /// Selected day within the editable block (for Overview → Edit navigation).
    var editableDayIndex: Int = 0
    /// Balance / coverage hints for the **currently selected** editable block.
    var generationBalanceWarnings: [SplitProposalProgramWarning] = []
    /// Actionable Checks suggestions across the whole program (deload + every block's balance notes).
    private(set) var programReviewSuggestions: [ProgramReviewSuggestion] = []

    /// Snapshot of the program right after successful generation (for Reset to generated).
    private(set) var generatedBaseline: DynamicProgram?
    private(set) var baselineEditableDays: [[SplitBuilderEditableDay]] = []
    /// Bounded undo stack of `(program, perBlockEditableDays, programRevision)` before structural mutations.
    /// `programRevision` is the revision that matched the snapshotted content (before the edit).
    private var undoStack: [(program: DynamicProgram, days: [[SplitBuilderEditableDay]], programRevision: Int)] = []
    private let maxUndoStackDepth = 20
    /// Transient banner after destructive edits (e.g. "Slot removed — Undo").
    var undoBannerMessage: String?
    /// Day to focus the next time a different block is selected (cross-block suggestion jumps).
    private var pendingEditDayIndex: Int?
    /// Debounce task for balance warning refresh.
    @ObservationIgnored private var balanceRefreshTask: Task<Void, Never>?

    /// Plain-language program layout (drives `request.blockSpecs` + `isPeriodized`).
    var programStructurePreset: ProgramStructurePreset = .singlePhase
    /// Total program length when using a fixed template (4/8/12/16) or the “Custom” bucket.
    var totalWeeksTemplate: TotalWeeksTemplate = .eight
    /// When `totalWeeksTemplate == .custom`, this is the total week count (1…52).
    var customTotalProgramWeeks: Int = 8
    /// When true, show per-block editors even for preset layouts (user chose “Customize phases”).
    var showPhaseCustomization: Bool = false
    /// User explicitly chose cardio inclusion on Essentials; skip goal-based auto defaults.
    var cardioPreferenceManuallySet = false

    private var didLoadPreferences = false
    private var didBootstrapFromContext = false

    /// One-line summary for live preview chips and floating action bar.
    var liveSummaryLine: String {
        let sessions = request.splitInput.sessionsPerWeek
        let split = shortSplitLabel(from: request.splitInput.splitPreference)
        let weeks = resolvedTotalProgramWeeks
        return "\(sessions) days/week · \(split) · \(weeks) weeks"
    }

    /// Resolved total weeks from the length picker.
    var resolvedTotalProgramWeeks: Int {
        switch totalWeeksTemplate {
        case .custom:
            return min(52, max(1, customTotalProgramWeeks))
        case .four, .six, .eight, .ten, .twelve, .sixteen:
            return totalWeeksTemplate.rawValue
        }
    }

    var hasCardioEnabled: Bool {
        CardioProgramPreference.fromStored(request.splitInput.cardioPreference) != .none
    }

    /// Applies cardio goal/preference from primary goal when user has not chosen inclusion yet.
    func applyGoalBasedCardioDefaults() {
        guard !cardioPreferenceManuallySet else { return }
        guard CardioProgramPreference.fromStored(request.splitInput.cardioPreference) == .none else { return }

        let goal = request.splitInput.primaryGoal.lowercased()
        if goal.contains("fat loss") || goal.contains("conditioning") {
            request.splitInput.cardioGoal = CardioProgramGoal.fatLoss.rawValue
            request.splitInput.cardioPreference = CardioProgramPreference.mixed.rawValue
        } else if goal.contains("athletic") || goal.contains("sport performance") {
            request.splitInput.cardioGoal = CardioProgramGoal.enduranceBuilding.rawValue
            request.splitInput.cardioPreference = CardioProgramPreference.mixed.rawValue
        } else if goal.contains("general fitness") || goal.contains("health") {
            request.splitInput.cardioGoal = CardioProgramGoal.generalHealth.rawValue
        }
    }

    /// Updates cardio goal when user opts into cardio on Essentials.
    func applyCardioGoalForCurrentPrimaryGoal() {
        let goal = request.splitInput.primaryGoal.lowercased()
        if goal.contains("fat loss") || goal.contains("conditioning") {
            request.splitInput.cardioGoal = CardioProgramGoal.fatLoss.rawValue
        } else if goal.contains("athletic") || goal.contains("sport performance") {
            request.splitInput.cardioGoal = CardioProgramGoal.enduranceBuilding.rawValue
        } else {
            request.splitInput.cardioGoal = CardioProgramGoal.generalHealth.rawValue
        }
    }

    func markCardioPreferenceCustomized() {
        cardioPreferenceManuallySet = true
    }

    init(request: DynamicProgramGenerationRequest = .simpleDefault()) {
        self.request = request
    }

    /// Loads saved wizard defaults, then infers from workout history when appropriate.
    func bootstrapFromContext(dataManager: DataManager) {
        guard !didBootstrapFromContext else { return }
        didBootstrapFromContext = true
        loadPreferencesIfNeeded()
        let saved = SplitBuilderPreferencesStore.load()
        let hasSavedPrefs = saved.experienceRaw != nil || saved.sessionsPerWeek != nil || saved.primaryGoalRaw != nil
        if !hasSavedPrefs {
            inferFromWorkoutHistory(dataManager: dataManager)
        }
        shouldPromoteQuickStart = !hasSavedPrefs && dataManager.completedSessions.filter(\.isCompleted).isEmpty
        if request.blockSpecs.isEmpty {
            applyProgramStructureSelections()
        }
    }

    func loadPreferencesIfNeeded() {
        guard !didLoadPreferences else { return }
        didLoadPreferences = true
        let s = SplitBuilderPreferencesStore.load()
        if let g = s.primaryGoalRaw { request.splitInput.primaryGoal = g }
        if let g = s.equipmentRaw { request.splitInput.equipment = g }
        if let g = s.splitPreferenceRaw { request.splitInput.splitPreference = g }
        if let g = s.experienceRaw { request.splitInput.experienceLevel = g }
        if let n = s.sessionsPerWeek {
            request.splitInput.sessionsPerWeek = min(max(1, n), 7)
        }
        if let w = s.selectedWeekdayNumbers {
            request.splitInput.preferredWeekdays = w.filter { $0 >= 1 && $0 <= 7 }.sorted()
        }
        if let t = s.limitationsNotes {
            request.splitInput.limitationsNotes = String(t.prefix(400))
        }
        if let t = s.additionalNotes {
            request.splitInput.additionalNotes = String(t.prefix(400))
        }
        if let raw = s.sessionDurationRaw {
            request.splitInput.sessionDurationMinutes = SessionDurationBuckets.minutes(fromPickerLabel: raw)
        }
        if let g = s.intensityStyleRaw { request.splitInput.intensityStyle = g }
        if let g = s.progressionStyleRaw { request.splitInput.progressionStyle = g }
        if let t = s.priorityMusclesOrLiftsNotes {
            request.splitInput.priorityMusclesOrLiftsNotes = String(t.prefix(400))
        }
        if let t = s.recoveryContextNotes {
            request.splitInput.recoveryContextNotes = String(t.prefix(400))
        }
        if let g = s.deloadPreferenceRaw { request.splitInput.deloadPreference = g }
        if let g = s.cardioPreferenceRaw { request.splitInput.cardioPreference = g }
        if let g = s.cardioGoalRaw { request.splitInput.cardioGoal = g }
        if let n = s.cardioDedicatedDayCount { request.splitInput.cardioDedicatedDayCount = n }
        if let n = s.cardioFinisherDurationMinutes { request.splitInput.cardioFinisherDurationMinutes = n }
        if let n = s.cardioFinisherZoneRaw { request.splitInput.cardioFinisherZoneRaw = n }
        if let n = s.cardioWeeklyProgressionMinutes { request.splitInput.cardioWeeklyProgressionMinutes = n }
        if CardioProgramPreference.fromStored(request.splitInput.cardioPreference) != .none {
            cardioPreferenceManuallySet = true
        }
        if let g = s.variationModeRaw { request.splitInput.variationMode = g }
        if let n = s.customRotationLength {
            request.splitInput.desiredWorkoutRotationLength = min(max(1, n), 7)
        }
        if let t = s.variationNotes {
            request.splitInput.variationNotes = String(t.prefix(400))
        }
        if let name = s.programName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            request.programName = name
        }
        if let raw = s.busyDayPolicyRaw, let pol = BusyDayPolicy(rawValue: raw) {
            request.busyDayPolicy = pol
        }
        if let json = s.dynamicBlockSpecsJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([PersistedDynamicBlockSpec].self, from: data),
           !decoded.isEmpty {
            request.blockSpecs = decoded.map { DynamicBlockGenerationSpec(persisted: $0) }
            if decoded.count > 1 {
                request.isPeriodized = true
            }
        }
        if let ip = s.isPeriodizedProgram {
            request.isPeriodized = ip
            if ip, request.blockSpecs.count < 2 {
                programStructurePreset = .twoPhases
                applyProgramStructureSelections()
            }
        }
        syncProgramStructureUIAfterLoadingPreferences()
        if let raw = s.programBuilderModeRaw?.lowercased() {
            if raw == "manual" { builderMode = .manualBuild }
            else { builderMode = .aiGenerate }
        }
    }

    func persistPreferencesToStore() {
        let specsData = try? JSONEncoder().encode(request.blockSpecs.map { $0.persistedSnapshot() })
        let specsJSON = specsData.flatMap { String(data: $0, encoding: .utf8) }
        var state = SplitBuilderPreferencesStore.load()
        state.primaryGoalRaw = request.splitInput.primaryGoal
        state.equipmentRaw = request.splitInput.equipment
        state.splitPreferenceRaw = request.splitInput.splitPreference
        state.experienceRaw = request.splitInput.experienceLevel
        state.sessionsPerWeek = request.splitInput.sessionsPerWeek
        state.selectedWeekdayNumbers = request.splitInput.preferredWeekdays
        state.limitationsNotes = request.splitInput.limitationsNotes
        state.additionalNotes = request.splitInput.additionalNotes
        state.sessionDurationRaw = SessionDurationBuckets.pickerLabel(fromMinutes: request.splitInput.sessionDurationMinutes)
        state.intensityStyleRaw = request.splitInput.intensityStyle
        state.progressionStyleRaw = request.splitInput.progressionStyle
        state.priorityMusclesOrLiftsNotes = request.splitInput.priorityMusclesOrLiftsNotes
        state.recoveryContextNotes = request.splitInput.recoveryContextNotes
        state.deloadPreferenceRaw = request.splitInput.deloadPreference
        state.cardioPreferenceRaw = request.splitInput.cardioPreference
        state.cardioGoalRaw = request.splitInput.cardioGoal
        state.cardioDedicatedDayCount = request.splitInput.cardioDedicatedDayCount
        state.cardioFinisherDurationMinutes = request.splitInput.cardioFinisherDurationMinutes
        state.cardioFinisherZoneRaw = request.splitInput.cardioFinisherZoneRaw
        state.cardioWeeklyProgressionMinutes = request.splitInput.cardioWeeklyProgressionMinutes
        state.variationModeRaw = request.splitInput.variationMode
        state.customRotationLength = request.splitInput.desiredWorkoutRotationLength
        state.variationNotes = request.splitInput.variationNotes
        state.programName = request.programName
        state.isPeriodizedProgram = request.isPeriodized
        state.busyDayPolicyRaw = request.busyDayPolicy.rawValue
        state.dynamicBlockSpecsJSON = specsJSON
        state.programBuilderModeRaw = builderMode == .manualBuild ? "manual" : "ai"
        SplitBuilderPreferencesStore.save(state)
    }

    /// Applies the current `programStructurePreset` + length to `request` (overwrites blocks except in some custom cases).
    func applyProgramStructureSelections() {
        let total = resolvedTotalProgramWeeks
        switch programStructurePreset {
        case .singlePhase:
            showPhaseCustomization = false
            request.isPeriodized = false
            request.blockSpecs = [
                DynamicBlockGenerationSpec(
                    title: "Training",
                    focus: BlockFocus(kind: .general, emphasisLabel: ""),
                    durationWeeks: total,
                    progressionStrategy: request.splitInput.resolvedProgressionStrategy()
                ),
            ]

        case .twoPhases:
            showPhaseCustomization = false
            request.isPeriodized = true
            let w1 = max(1, total / 2)
            let w2 = max(1, total - w1)
            request.blockSpecs = [
                DynamicBlockGenerationSpec(
                    title: "Phase 1: Build muscle",
                    focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                    durationWeeks: w1,
                    progressionStrategy: .doubleProgression
                ),
                DynamicBlockGenerationSpec(
                    title: "Phase 2: Get stronger",
                    focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                    durationWeeks: w2,
                    progressionStrategy: .linear
                ),
            ]

        case .threePhases:
            showPhaseCustomization = false
            request.isPeriodized = true
            let w1 = max(1, (total * 2) / 5)
            let w2 = max(1, (total * 2) / 5)
            let w3 = max(1, total - w1 - w2)
            request.blockSpecs = [
                DynamicBlockGenerationSpec(
                    title: "Phase 1: Build muscle",
                    focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                    durationWeeks: w1,
                    progressionStrategy: .doubleProgression
                ),
                DynamicBlockGenerationSpec(
                    title: "Phase 2: Get stronger",
                    focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                    durationWeeks: w2,
                    progressionStrategy: .linear
                ),
                DynamicBlockGenerationSpec(
                    title: "Phase 3: Recovery",
                    focus: BlockFocus(kind: .deload, emphasisLabel: ""),
                    durationWeeks: w3,
                    progressionStrategy: .doubleProgression,
                    volumeMultiplier: 0.72,
                    isDeloadBlock: true
                ),
            ]

        case .custom:
            request.isPeriodized = request.blockSpecs.count > 1
            if request.blockSpecs.isEmpty {
                let w1 = max(1, total / 2)
                let w2 = max(1, total - w1)
                request.blockSpecs = [
                    DynamicBlockGenerationSpec(
                        title: "Phase 1",
                        focus: BlockFocus(kind: .general, emphasisLabel: ""),
                        durationWeeks: w1,
                        progressionStrategy: request.splitInput.resolvedProgressionStrategy()
                    ),
                    DynamicBlockGenerationSpec(
                        title: "Phase 2",
                        focus: BlockFocus(kind: .general, emphasisLabel: ""),
                        durationWeeks: w2,
                        progressionStrategy: request.splitInput.resolvedProgressionStrategy()
                    ),
                ]
                request.isPeriodized = true
            }
        }
    }

    func applyProgramStructurePresetChange(from previous: ProgramStructurePreset) {
        if programStructurePreset == .custom {
            if previous != .custom, request.blockSpecs.count < 2 {
                applyProgramStructureSelections()
            } else {
                request.isPeriodized = request.blockSpecs.count > 1
            }
            return
        }
        showPhaseCustomization = false
        applyProgramStructureSelections()
    }

    func applyTotalWeeksOrLengthChange() {
        guard programStructurePreset != .custom else {
            request.isPeriodized = request.blockSpecs.count > 1
            return
        }
        applyProgramStructureSelections()
    }

    /// Merges a saved split preset into schedule fields and hydrates the first block's rotation days.
    func applySavedPreset(name: String, days: [SplitBuilderEditableDay], sessionsPerWeek: Int, preferredWeekdays: [Int]) {
        request.splitInput.sessionsPerWeek = min(max(1, sessionsPerWeek), 7)
        request.splitInput.preferredWeekdays = preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName = DynamicProgramGenerationRequest.simpleDefault().programName
        if request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || request.programName == defaultName {
            request.programName = trimmedName.isEmpty ? defaultName : trimmedName
        }

        ensureManualDraftIfNeeded()
        if generatedProgram == nil {
            if request.blockSpecs.isEmpty {
                applyProgramStructureSelections()
            }
            generatedProgram = DynamicProgramMapper.blankProgram(from: request)
        }
        guard generatedProgram != nil else { return }

        if perBlockEditableDays.isEmpty {
            perBlockEditableDays = [days]
        } else {
            perBlockEditableDays[0] = days
        }
        persistPerBlockTemplatesIntoProgram()
        refreshGenerationBalanceWarnings()
        wizardStep = .reviewAndEdit
        errorMessage = nil
    }

    private func syncProgramStructureUIAfterLoadingPreferences() {
        let sum = request.blockSpecs.map(\.durationWeeks).reduce(0, +)
        if sum > 0 {
            customTotalProgramWeeks = sum
            switch sum {
            case 4: totalWeeksTemplate = .four
            case 8: totalWeeksTemplate = .eight
            case 12: totalWeeksTemplate = .twelve
            case 16: totalWeeksTemplate = .sixteen
            default:
                totalWeeksTemplate = .custom
            }
        }

        if !request.isPeriodized {
            programStructurePreset = .singlePhase
        } else if request.blockSpecs.count == 2 {
            programStructurePreset = .twoPhases
        } else if request.blockSpecs.count >= 3,
                  request.blockSpecs.last?.isDeloadBlock == true || request.blockSpecs.last?.focus.kind == .deload {
            programStructurePreset = .threePhases
        } else if request.blockSpecs.count >= 2 {
            programStructurePreset = .custom
        } else {
            programStructurePreset = .singlePhase
        }
    }

    /// Loads a persisted active program into the wizard preview step for editing and re-apply.
    func hydrate(from state: DynamicProgramState) {
        generatedProgram = state.program
        programAnchorDate = state.anchorDate
        request.programName = state.program.name
        request.splitInput.sessionsPerWeek = state.program.defaultSessionsPerWeek
        request.splitInput.preferredWeekdays = state.program.preferredWeekdays
        request.busyDayPolicy = state.program.busyDayPolicy
        request.isPeriodized = state.program.blocks.count > 1
        request.blockSpecs = state.program.blocks.map { block in
            DynamicBlockGenerationSpec(
                title: block.name,
                focus: block.focus,
                durationWeeks: block.durationWeeks,
                progressionStrategy: block.progressionStrategy,
                volumeMultiplier: block.volumeMultiplier,
                isDeloadBlock: block.isDeloadBlock,
                cardioGoal: block.cardioGoal,
                cardioPreference: block.cardioPreference,
                cardioDedicatedDayCount: block.cardioDedicatedDayCount,
                cardioFinisherDurationMinutes: block.cardioFinisherDurationMinutes,
                cardioFinisherZone: block.cardioFinisherZone,
                cardioWeeklyProgressionMinutes: block.cardioWeeklyProgressionMinutes
            )
        }
        syncProgramStructureUIAfterLoadingPreferences()
        errorMessage = nil
        applyErrorMessage = nil
        editableBlockIndex = 0
        rebuildEditableDaysFromProgram()
        captureGeneratedBaseline()
        wizardStep = .reviewAndEdit
        builderMode = state.program.generatedWithAI ? .aiGenerate : .manualBuild
        markProgramSaved()
    }

    func applyCuratedTemplate(
        _ template: CuratedProgramTemplate,
        overrideWeeks: Int? = nil,
        overrideSessions: Int? = nil
    ) {
        request = template.buildRequest()
        builderMode = .aiGenerate
        programStructurePreset = template.programStructure
        request.isPeriodized = template.isPeriodized
        if let overrideWeeks {
            customTotalProgramWeeks = overrideWeeks
            switch overrideWeeks {
            case 4: totalWeeksTemplate = .four
            case 8: totalWeeksTemplate = .eight
            case 12: totalWeeksTemplate = .twelve
            case 16: totalWeeksTemplate = .sixteen
            default:
                totalWeeksTemplate = .custom
            }
        } else {
            customTotalProgramWeeks = template.totalWeeks
            switch template.totalWeeks {
            case 4: totalWeeksTemplate = .four
            case 8: totalWeeksTemplate = .eight
            case 12: totalWeeksTemplate = .twelve
            case 16: totalWeeksTemplate = .sixteen
            default:
                totalWeeksTemplate = .custom
            }
        }
        if let overrideSessions {
            request.splitInput.sessionsPerWeek = min(max(1, overrideSessions), 7)
        }
        applyProgramStructureSelections()
        wizardStep = .reviewAndEdit
        errorMessage = nil
    }

    func applyExperienceBasedDefaults() {
        let exp = request.splitInput.experienceLevel.lowercased()
        if exp.contains("beginner") {
            request.splitInput.sessionsPerWeek = 3
            request.splitInput.splitPreference = "Full body"
            totalWeeksTemplate = .eight
            programStructurePreset = .singlePhase
        } else if exp.contains("advanced") {
            if request.splitInput.sessionsPerWeek < 4 {
                request.splitInput.sessionsPerWeek = 5
            }
            if request.splitInput.splitPreference.contains("No preference") {
                request.splitInput.splitPreference = "Push / Pull / Legs"
            }
            totalWeeksTemplate = .twelve
        } else {
            if request.splitInput.sessionsPerWeek < 3 {
                request.splitInput.sessionsPerWeek = 4
            }
            if request.splitInput.splitPreference.contains("No preference") {
                request.splitInput.splitPreference = "Upper / Lower"
            }
            totalWeeksTemplate = .eight
        }
        customTotalProgramWeeks = resolvedTotalProgramWeeks
        applyProgramStructureSelections()
    }

    func inferFromWorkoutHistory(dataManager: DataManager) {
        let completed = dataManager.completedSessions.filter(\.isCompleted)
        guard !completed.isEmpty else { return }

        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let recent = completed.filter { ($0.endTime ?? Date()) >= cutoff }
        if !recent.isEmpty {
            let avg = max(1, min(7, recent.count / 4))
            request.splitInput.sessionsPerWeek = avg
        }

        if dataManager.trainingProgram.sessionsPerWeek > 0 {
            request.splitInput.sessionsPerWeek = dataManager.trainingProgram.sessionsPerWeek
        }
        if !dataManager.trainingProgram.preferredWeekdays.isEmpty {
            request.splitInput.preferredWeekdays = dataManager.trainingProgram.preferredWeekdays
        }

        let totalSets = completed.reduce(0) { partial, session in
            partial + session.exerciseLogs.reduce(0) { $0 + $1.loggedSets.count }
        }
        let avgSetsPerSession = totalSets / max(1, completed.count)
        if avgSetsPerSession >= 18 {
            request.splitInput.experienceLevel = "Advanced"
        } else if avgSetsPerSession >= 10 {
            request.splitInput.experienceLevel = "Intermediate"
        } else {
            request.splitInput.experienceLevel = "Beginner"
        }
        applyExperienceBasedDefaults()
    }

    func generate(aiService: AIService, dataManager: DataManager, entitlementStore: EntitlementStore) async {
        guard !isGenerating else { return }
        guard entitlementStore.hasAccess(to: .aiProgramGeneration) else {
            errorMessage = "Upgrade to Premium to generate programs with AI."
            return
        }
        errorMessage = nil
        offersLocalPresetFallback = false
        isGenerating = true
        lastGenerationUsedLocalPresets = false
        generationBlockCompleted = 0
        generationBlockTotal = 1
        setGenerationStage(.idle)
        defer {
            isGenerating = false
            isConnectingToProxy = false
            // Keep stage/counters visible until the host navigates or the next run starts.
        }

        if aiService.isConfigured {
            isConnectingToProxy = true
            setGenerationStage(.connecting)
            await aiService.ensureProxyAwake()
            isConnectingToProxy = false
        } else {
            aiService.wakeProxyHostIfNeeded()
        }

        if request.blockSpecs.count == 1 {
            request.blockSpecs[0].progressionStrategy = request.splitInput.resolvedProgressionStrategy()
        }

        let allowed = dataManager.globalExercises.map(\.name).sorted()
        let existingTemplates = dataManager.userWorkouts.map(\.name)
        let library = dataManager.globalExercises
        let blockCount = request.isPeriodized && request.blockSpecs.count > 1 ? request.blockSpecs.count : 1
        generationBlockTotal = blockCount
        generationBlockCompleted = 0
        setGenerationStage(.designing)
        if blockCount > 1 {
            generationStatusMessage = "Generating phase 1 of \(blockCount)…"
        }

        do {
            let program = try await aiService.generateDynamicProgram(
                request: request,
                allowedExerciseNames: allowed,
                existingWorkoutTemplateNames: existingTemplates,
                exerciseLibrary: library,
                onBlockProgress: { completed, total in
                    Task { @MainActor in
                        guard self.generationStage == .designing else { return }
                        self.generationBlockCompleted = completed
                        self.generationBlockTotal = total
                        self.generationStatusMessage = "Generating phase \(min(completed + 1, total)) of \(total)…"
                    }
                }
            )
            generationBlockCompleted = blockCount
            generatedProgram = program
            applyErrorMessage = nil
            generationSuccessCount += 1
            lastGenerationUsedLocalPresets = !aiService.isConfigured
            editableBlockIndex = 0
            setGenerationStage(.finalizing)
            rebuildEditableDaysFromProgram()
            captureGeneratedBaseline()
            setGenerationStage(.ready)
        } catch {
            generatedProgram = nil
            perBlockEditableDays = []
            generationBalanceWarnings = []
            programReviewSuggestions = []
            clearGeneratedBaseline()
            setGenerationStage(.idle)
            generationBlockCompleted = 0
            generationBlockTotal = 1
            if let aiError = error as? AIServiceError {
                errorMessage = aiError.errorDescription
                offersLocalPresetFallback = aiError.suggestsLocalPresetFallback && aiService.isConfigured
            } else {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                offersLocalPresetFallback = aiService.isConfigured
            }
        }
    }

    /// Builds a program from FitLog’s built-in rotation presets (no network).
    func generateFromLocalPresets(dataManager: DataManager) async {
        guard !isGenerating else { return }
        errorMessage = nil
        offersLocalPresetFallback = false
        isGenerating = true
        lastGenerationUsedLocalPresets = false
        generationBlockCompleted = 0
        generationBlockTotal = 1
        setGenerationStage(.designing)
        defer {
            isGenerating = false
        }

        if request.blockSpecs.count == 1 {
            request.blockSpecs[0].progressionStrategy = request.splitInput.resolvedProgressionStrategy()
        }

        let library = dataManager.globalExercises
        let multi = request.isPeriodized && request.blockSpecs.count > 1
        let proposal = DynamicProgramMapper.localWorkoutSplitProposal(from: request.splitInput, library: library)
        var program: DynamicProgram
        if multi {
            program = DynamicProgramMapper.multiBlock(from: proposal, request: request, library: library)
        } else {
            program = DynamicProgramMapper.singleBlock(from: proposal, request: request, library: library)
        }
        program.generatedWithAI = false
        generationBlockCompleted = 1
        generatedProgram = program
        applyErrorMessage = nil
        generationSuccessCount += 1
        lastGenerationUsedLocalPresets = true
        editableBlockIndex = 0
        setGenerationStage(.finalizing)
        rebuildEditableDaysFromProgram()
        captureGeneratedBaseline()
        setGenerationStage(.ready)
    }

    func setGenerationStage(_ stage: GenerationStage) {
        generationStage = stage
        switch stage {
        case .idle:
            generationStatusMessage = nil
        case .connecting, .designing, .finalizing, .ready:
            generationStatusMessage = stage.statusLine
        }
    }

    /// Clears progress UI state after the host navigates away from the generating screen.
    func resetGenerationProgressUI() {
        generationStage = .idle
        generationStatusMessage = nil
        generationBlockCompleted = 0
        generationBlockTotal = 1
        isConnectingToProxy = false
    }

    func rebuildEditableDaysFromProgram() {
        guard let prog = generatedProgram else {
            perBlockEditableDays = []
            generationBalanceWarnings = []
            programReviewSuggestions = []
            return
        }
        editableBlockIndex = min(max(0, editableBlockIndex), prog.blocks.count - 1)
        perBlockEditableDays = prog.blocks.map { block in
            block.weeklyTemplates.map { t in
                SplitBuilderEditableDay(id: t.id, name: t.dayName, focus: t.focus, slots: t.slots, dayNotes: t.dayNotes)
            }
        }
        refreshGenerationBalanceWarnings()
    }

    /// Two-way binding for a block’s editable template days (timeline + form share this).
    /// Field edits update `perBlockEditableDays` only; persist/analyze on commit points.
    func bindingForBlockDays(_ blockIndex: Int) -> Binding<[SplitBuilderEditableDay]> {
        Binding(
            get: {
                guard self.perBlockEditableDays.indices.contains(blockIndex) else { return [] }
                return self.perBlockEditableDays[blockIndex]
            },
            set: { newVal in
                guard self.perBlockEditableDays.indices.contains(blockIndex) else { return }
                self.perBlockEditableDays[blockIndex] = newVal
            }
        )
    }

    /// Persist editable days into `generatedProgram` (call on sheet dismiss, structural change, block switch, save).
    func persistPerBlockTemplatesIntoProgram() {
        guard var prog = generatedProgram else { return }
        for i in prog.blocks.indices {
            guard perBlockEditableDays.indices.contains(i) else { continue }
            prog.blocks[i].weeklyTemplates = perBlockEditableDays[i].map { d in
                BlockWeeklyTemplate(id: d.id, dayName: d.name, focus: d.focus, slots: d.slots, dayNotes: d.dayNotes)
            }
        }
        generatedProgram = prog
    }

    /// Structural edit commit: persist + refresh balance warnings immediately.
    func commitStructuralEdit(banner: String? = nil) {
        persistPerBlockTemplatesIntoProgram()
        refreshGenerationBalanceWarnings()
        if let banner {
            undoBannerMessage = banner
        }
    }

    /// Field edit commit: persist + debounced balance refresh.
    func commitFieldEdit() {
        persistPerBlockTemplatesIntoProgram()
        markProgramChanged()
        scheduleDebouncedBalanceRefresh()
    }

    private func scheduleDebouncedBalanceRefresh() {
        balanceRefreshTask?.cancel()
        balanceRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            refreshGenerationBalanceWarnings()
        }
    }

    /// Flattened templates for apply confirmation / conflict diff (all blocks in order).
    func flattenedEditableDaysForConfirmation() -> [SplitBuilderEditableDay] {
        perBlockEditableDays.flatMap(\.self)
    }

    func selectEditableBlock(_ index: Int) {
        persistPerBlockTemplatesIntoProgram()
        editableBlockIndex = min(max(0, index), max(0, (generatedProgram?.blocks.count ?? 1) - 1))
        if let pending = pendingEditDayIndex,
           perBlockEditableDays.indices.contains(editableBlockIndex),
           perBlockEditableDays[editableBlockIndex].indices.contains(pending) {
            editableDayIndex = pending
        } else {
            editableDayIndex = 0
        }
        pendingEditDayIndex = nil
        refreshGenerationBalanceWarnings()
    }

    func selectEditableDay(_ dayIndex: Int) {
        guard perBlockEditableDays.indices.contains(editableBlockIndex),
              perBlockEditableDays[editableBlockIndex].indices.contains(dayIndex) else { return }
        editableDayIndex = dayIndex
    }

    func refreshGenerationBalanceWarnings() {
        generationBalanceWarnings = balanceWarningsForBlock(at: editableBlockIndex)
        programReviewSuggestions = computeProgramReviewSuggestions()
    }

    // MARK: - Baseline / Undo

    var canUndo: Bool { !undoStack.isEmpty }
    var canResetToGenerated: Bool { generatedBaseline != nil }

    func captureGeneratedBaseline() {
        markProgramChanged()
        guard let prog = generatedProgram else {
            clearGeneratedBaseline()
            return
        }
        generatedBaseline = prog
        baselineEditableDays = perBlockEditableDays
        undoStack.removeAll()
        undoBannerMessage = nil
    }

    func clearGeneratedBaseline() {
        generatedBaseline = nil
        baselineEditableDays = []
        undoStack.removeAll()
        undoBannerMessage = nil
    }

    /// Push current state before a structural mutation.
    func pushUndoSnapshot() {
        guard let prog = generatedProgram else { return }
        let revisionAtSnapshot = programRevision
        markProgramChanged()
        undoStack.append((program: prog, days: perBlockEditableDays, programRevision: revisionAtSnapshot))
        if undoStack.count > maxUndoStackDepth {
            undoStack.removeFirst(undoStack.count - maxUndoStackDepth)
        }
    }

    @discardableResult
    func undoLastEdit() -> Bool {
        guard let snapshot = undoStack.popLast() else { return false }
        generatedProgram = snapshot.program
        perBlockEditableDays = snapshot.days
        programRevision = snapshot.programRevision
        editableBlockIndex = min(editableBlockIndex, max(0, perBlockEditableDays.count - 1))
        editableDayIndex = 0
        refreshGenerationBalanceWarnings()
        undoBannerMessage = nil
        return true
    }

    @discardableResult
    func resetToGenerated() -> Bool {
        guard let baseline = generatedBaseline else { return false }
        pushUndoSnapshot()
        generatedProgram = baseline
        perBlockEditableDays = baselineEditableDays
        editableBlockIndex = 0
        editableDayIndex = 0
        refreshGenerationBalanceWarnings()
        undoBannerMessage = "Reset to generated program"
        return true
    }

    func dismissUndoBanner() {
        undoBannerMessage = nil
    }

    /// Inserts a complementary empty strength slot on a day (for actionable balance suggestions).
    @discardableResult
    func addComplementarySlot(dayIndex: Int, label: String, muscles: [String]) -> UUID? {
        guard perBlockEditableDays.indices.contains(editableBlockIndex),
              perBlockEditableDays[editableBlockIndex].indices.contains(dayIndex) else { return nil }
        pushUndoSnapshot()
        let slot = SplitBuilderEditableSlot(
            label: label,
            targetMuscleNames: muscles.isEmpty ? [MuscleGroup.other.rawValue] : muscles,
            sets: 3,
            reps: "8-12"
        )
        perBlockEditableDays[editableBlockIndex][dayIndex].slots.append(slot)
        editableDayIndex = dayIndex
        commitStructuralEdit(banner: "Added “\(label)” — Undo")
        return slot.id
    }

    /// Focuses a day for the edit surface. Defers to `pendingEditDayIndex` only when the day
    /// isn't reachable yet, so a stale index can't hijack a later block switch.
    func openDayFromSuggestion(dayIndex: Int) {
        guard perBlockEditableDays.indices.contains(editableBlockIndex),
              perBlockEditableDays[editableBlockIndex].indices.contains(dayIndex) else {
            pendingEditDayIndex = dayIndex
            return
        }
        pendingEditDayIndex = nil
        editableDayIndex = dayIndex
    }

    func appendRegenerateConstraint(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = request.splitInput.adjustmentInstruction?.trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            request.splitInput.adjustmentInstruction = existing + "\n\n" + trimmed
        } else {
            request.splitInput.adjustmentInstruction = trimmed
        }
    }

    func balanceWarningsForBlock(at blockIndex: Int) -> [SplitProposalProgramWarning] {
        guard let prog = generatedProgram, prog.blocks.indices.contains(blockIndex),
              perBlockEditableDays.indices.contains(blockIndex) else {
            return []
        }
        let templates = perBlockEditableDays[blockIndex]
        let days = templates.map { t in
            SplitProposalProgramAnalyzer.DayInput(
                name: t.name,
                focus: t.focus,
                slots: t.slots.map {
                    SplitProposalProgramAnalyzer.SlotInput(
                        label: $0.label,
                        targetMuscleNames: $0.targetMuscleNames,
                        sets: $0.sets
                    )
                }
            )
        }
        let stats = SplitProposalProgramAnalyzer.stats(for: days)
        let ctx = SplitProposalProgramAnalyzer.Context(
            primaryGoal: request.splitInput.primaryGoal,
            experienceLevel: request.splitInput.experienceLevel,
            sessionDurationMinutes: request.splitInput.sessionDurationMinutes,
            priorityNotes: request.splitInput.priorityMusclesOrLiftsNotes,
            variationMode: request.splitInput.variationMode,
            sessionsPerWeek: prog.defaultSessionsPerWeek,
            desiredRotationLength: request.splitInput.desiredWorkoutRotationLength,
            splitPreference: request.splitInput.splitPreference
        )
        return SplitProposalProgramAnalyzer.warnings(stats: stats, days: days, context: ctx)
    }

    /// Balance warnings across every block (for Overview Checks).
    func balanceWarningsForAllBlocks() -> [(blockIndex: Int, warning: SplitProposalProgramWarning)] {
        guard let prog = generatedProgram else { return [] }
        var result: [(blockIndex: Int, warning: SplitProposalProgramWarning)] = []
        for index in prog.blocks.indices {
            for warning in balanceWarningsForBlock(at: index) {
                result.append((blockIndex: index, warning: warning))
            }
        }
        return result
    }

    /// Unified Checks suggestions: program-wide deload + per-block balance notes.
    /// Recomputed at commit points (see `refreshGenerationBalanceWarnings`) rather than per body
    /// evaluation, because analyzing every block is too expensive to run on each keystroke.
    private func computeProgramReviewSuggestions() -> [ProgramReviewSuggestion] {
        guard let prog = generatedProgram else { return [] }
        var items: [ProgramReviewSuggestion] = []

        let totalWeeks = prog.blocks.reduce(0) { $0 + max(1, $1.durationWeeks) }
        let hasDeload = prog.blocks.contains { $0.isDeloadBlock || $0.focus.kind == .deload }
        if totalWeeks >= 8, !hasDeload {
            items.append(
                ProgramReviewSuggestion(
                    id: "program|deload",
                    message: "Programs 8+ weeks often benefit from a planned deload phase.",
                    fixSummary: ProgramReviewSuggestion.fixSummary(for: .addDeloadPhase),
                    action: .addDeloadPhase,
                    blockIndex: nil,
                    severity: .note
                )
            )
        }

        let multiBlock = prog.blocks.count > 1
        let allWarnings = balanceWarningsForAllBlocks()
        let caution = allWarnings.filter { $0.warning.severity == .caution }
        let notes = allWarnings.filter { $0.warning.severity == .note }
        for entry in caution + notes {
            let prefix = multiBlock ? prog.blocks[entry.blockIndex].name : nil
            items.append(
                ProgramReviewSuggestion(
                    warning: entry.warning,
                    blockIndex: entry.blockIndex,
                    blockNamePrefix: prefix
                )
            )
        }
        return items
    }

    /// Appends a 1-week deload phase, shrinking the last block when it has ≥2 weeks.
    @discardableResult
    func applyAddDeloadPhase() -> Bool {
        persistPerBlockTemplatesIntoProgram()
        guard var prog = generatedProgram, let last = prog.blocks.last else { return false }
        if last.isDeloadBlock || last.focus.kind == .deload { return false }

        pushUndoSnapshot()
        var workingLast = last
        if workingLast.durationWeeks >= 2 {
            workingLast.durationWeeks -= 1
            prog.blocks[prog.blocks.count - 1] = workingLast
        }

        let deload = ProgramBlock(
            name: "Deload",
            focus: BlockFocus(kind: .deload, emphasisLabel: ""),
            durationWeeks: 1,
            weeklyTemplates: DynamicProgramMapper.duplicateWeeklyTemplates(workingLast.weeklyTemplates),
            progressionStrategy: .doubleProgression,
            isDeloadBlock: true,
            volumeMultiplier: 0.7,
            notes: "Lighter recovery week — keep form crisp and leave reps in reserve."
        )
        prog.blocks.append(deload)
        generatedProgram = prog
        rebuildEditableDaysFromProgram()
        selectEditableBlock(prog.blocks.count - 1)
        undoBannerMessage = "Added deload phase — Undo"
        return true
    }

    /// Raises weekly hard-set volume on a block by incrementing the lowest-set strength slots first.
    @discardableResult
    func applyRaiseWeeklyVolume(targetHardSets: Int, blockIndex: Int? = nil) -> Bool {
        let index = blockIndex ?? editableBlockIndex
        guard perBlockEditableDays.indices.contains(index) else { return false }

        func hardSets(in days: [SplitBuilderEditableDay]) -> Int {
            days.reduce(0) { partial, day in
                partial + day.slots.reduce(0) { sum, slot in
                    guard slot.modality != .cardio else { return sum }
                    return sum + max(0, slot.sets)
                }
            }
        }

        var days = perBlockEditableDays[index]
        var current = hardSets(in: days)
        guard current > 0, current < targetHardSets else { return false }

        let setCap = 5
        var addedSets = 0
        while current < targetHardSets {
            var pick: (day: Int, slot: Int, sets: Int)?
            for (dayIndex, day) in days.enumerated() {
                for (slotIndex, slot) in day.slots.enumerated() {
                    guard slot.modality != .cardio, slot.sets < setCap else { continue }
                    if pick == nil || slot.sets < pick!.sets {
                        pick = (dayIndex, slotIndex, slot.sets)
                    }
                }
            }
            // Every strength slot is already at the cap — raising volume needs more exercises.
            guard let pick else { break }
            days[pick.day].slots[pick.slot].sets += 1
            current += 1
            addedSets += 1
        }
        guard addedSets > 0 else { return false }

        pushUndoSnapshot()
        perBlockEditableDays[index] = days
        editableBlockIndex = index
        commitStructuralEdit(banner: "Raised weekly volume — Undo")
        return true
    }

    /// Validation for save / apply (blocking vs warnings).
    var programValidationResult: ProgramValidationResult {
        ProgramValidationResult.evaluate(
            programName: request.programName,
            program: generatedProgram,
            perBlockEditableDays: perBlockEditableDays,
            balanceWarnings: generationBalanceWarnings,
            isManualMode: builderMode == .manualBuild
        )
    }

    func applyToPlan(dataManager: DataManager, anchorDate: Date? = nil) {
        persistPerBlockTemplatesIntoProgram()
        guard let program = generatedProgram else { return }
        let validation = programValidationResult
        guard validation.canSaveToPlan else {
            applyErrorMessage = validation.blockingIssues.first ?? "Fix validation issues before saving."
            return
        }
        let anchor = anchorDate.map { Calendar.current.startOfDay(for: $0) } ?? programAnchorDate
        applyErrorMessage = nil
        isApplying = true
        defer { isApplying = false }

        guard dataManager.applyDynamicProgram(program, anchorDate: anchor) else {
            applyErrorMessage = "Could not create every workout template from the generated program. Try generating again, or adjust templates in the preview step."
            return
        }
        programAnchorDate = anchor
        applySuccessCount += 1
        markProgramSaved()
        applySavedDetail = "Templates were added to your workout list and your Plan rotation matches the current program block."
        showApplySavedAlert = true
    }

    /// Ensures manual mode has an editable in-memory program (blank skeleton) without calling AI.
    func ensureManualDraftIfNeeded() {
        guard builderMode == .manualBuild else { return }
        guard generatedProgram == nil else { return }
        if request.blockSpecs.isEmpty {
            applyProgramStructureSelections()
        }
        generatedProgram = DynamicProgramMapper.blankProgram(from: request)
        lastGenerationUsedLocalPresets = true
        errorMessage = nil
        editableBlockIndex = 0
        rebuildEditableDaysFromProgram()
        captureGeneratedBaseline()
    }

    /// Inserts a duplicate of the block at `index` with fresh template and slot ids.
    func duplicateProgramBlock(at index: Int) {
        guard generatedProgram != nil, generatedProgram!.blocks.indices.contains(index) else { return }
        persistPerBlockTemplatesIntoProgram()
        guard var prog = generatedProgram else { return }
        pushUndoSnapshot()
        let b = prog.blocks[index]
        let warmup = b.warmUpTemplate.map { $0.map { $0.withNewSlotId() } }
        let cooldown = b.cooldownTemplate.map { $0.map { $0.withNewSlotId() } }
        let copy = ProgramBlock(
            id: UUID(),
            name: duplicateBlockName(from: b.name),
            focus: b.focus,
            durationWeeks: b.durationWeeks,
            weeklyTemplates: DynamicProgramMapper.duplicateWeeklyTemplates(b.weeklyTemplates),
            progressionStrategy: b.progressionStrategy,
            isDeloadBlock: b.isDeloadBlock,
            volumeMultiplier: b.volumeMultiplier,
            deloadWeekNumber: b.deloadWeekNumber,
            notes: b.notes,
            warmUpTemplate: warmup,
            cooldownTemplate: cooldown
        )
        prog.blocks.insert(copy, at: index + 1)
        generatedProgram = prog
        rebuildEditableDaysFromProgram()
        selectEditableBlock(index + 1)
    }

    /// Replaces the block at `index` rotation with a deep copy of the previous block’s templates.
    func copyWeeklyTemplatesFromPreviousBlock(into index: Int) {
        guard index > 0, generatedProgram != nil, generatedProgram!.blocks.indices.contains(index) else { return }
        persistPerBlockTemplatesIntoProgram()
        guard var prog = generatedProgram else { return }
        pushUndoSnapshot()
        let prev = prog.blocks[index - 1]
        prog.blocks[index].weeklyTemplates = DynamicProgramMapper.duplicateWeeklyTemplates(prev.weeklyTemplates)
        generatedProgram = prog
        rebuildEditableDaysFromProgram()
        selectEditableBlock(index)
    }

    /// Replaces the block’s rotation with a single template day built from a library workout.
    func importRotationFromWorkout(_ workout: Workout, blockIndex: Int, exerciseLibrary: [Exercise]) {
        guard generatedProgram != nil, generatedProgram!.blocks.indices.contains(blockIndex) else { return }
        persistPerBlockTemplatesIntoProgram()
        guard var prog = generatedProgram else { return }
        pushUndoSnapshot()
        var slots: [SplitBuilderEditableSlot] = []
        slots.reserveCapacity(workout.exercises.count)
        for row in workout.exercises {
            switch row.resolution {
            case .concrete(let snap):
                let ex = exerciseLibrary.first(where: { $0.id == snap.exerciseId })
                let muscles = ex?.targetedMuscles.map(\.rawValue) ?? [MuscleGroup.other.rawValue]
                slots.append(
                    SplitBuilderEditableSlot(
                        label: snap.nameAtTimeOfLog,
                        targetMuscleNames: muscles,
                        sets: row.recommendedSets,
                        reps: row.recommendedReps,
                        suggestedExerciseName: ex?.name ?? snap.nameAtTimeOfLog,
                        suggestedExerciseOverrideId: snap.exerciseId
                    )
                )
            case .flexible(let bp):
                let muscles = bp.targetedMuscles.map(\.rawValue)
                let ex = bp.defaultExerciseId.flatMap { id in exerciseLibrary.first(where: { $0.id == id }) }
                slots.append(
                    SplitBuilderEditableSlot(
                        label: bp.label,
                        targetMuscleNames: muscles.isEmpty ? [MuscleGroup.other.rawValue] : muscles,
                        sets: row.recommendedSets,
                        reps: row.recommendedReps,
                        suggestedExerciseName: ex?.name,
                        suggestedExerciseOverrideId: bp.defaultExerciseId
                    )
                )
            }
        }
        let day = BlockWeeklyTemplate(dayName: workout.name, focus: "", slots: slots)
        prog.blocks[blockIndex].weeklyTemplates = [day]
        generatedProgram = prog
        rebuildEditableDaysFromProgram()
        selectEditableBlock(blockIndex)
    }

    private func duplicateBlockName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Block" : trimmed
        if base.lowercased().hasSuffix(" copy") { return base }
        return "\(base) copy"
    }

    private func shortSplitLabel(from preference: String) -> String {
        let lower = preference.lowercased()
        if lower.contains("push") && lower.contains("pull") { return "PPL" }
        if lower.contains("upper") && lower.contains("lower") { return "Upper/Lower" }
        if lower.contains("full") { return "Full body" }
        if lower.contains("bro") || lower.contains("muscle group") { return "Bro split" }
        if lower.contains("no preference") { return "Auto split" }
        return preference
    }

}
