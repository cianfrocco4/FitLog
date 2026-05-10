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
        case eight = 8
        case twelve = 12
        case sixteen = 16
        case custom = 0

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .four: return "4 weeks"
            case .eight: return "8 weeks"
            case .twelve: return "12 weeks"
            case .sixteen: return "16 weeks"
            case .custom: return "Custom"
            }
        }
    }

    enum WizardStep: Int, CaseIterable, Identifiable, Hashable {
        case goals = 0
        case programType = 1
        case schedule = 2
        case busyDays = 3
        case generatePreview = 4

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .goals: return "Goals"
            case .programType: return "Program"
            case .schedule: return "Schedule"
            case .busyDays: return "Busy days"
            case .generatePreview: return "Preview"
            }
        }
    }

    var request: DynamicProgramGenerationRequest
    var wizardStep: WizardStep = .goals

    var generatedProgram: DynamicProgram?
    var errorMessage: String?
    var isGenerating = false
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

    /// Editable weekly templates for **each** program block (source of truth for preview + timeline editing).
    var perBlockEditableDays: [[SplitBuilderEditableDay]] = []
    /// Which program block the main “Templates” form section is editing (0-based).
    var editableBlockIndex: Int = 0
    /// Balance / coverage hints for the **currently selected** editable block.
    var generationBalanceWarnings: [SplitProposalProgramWarning] = []

    /// Plain-language program layout (drives `request.blockSpecs` + `isPeriodized`).
    var programStructurePreset: ProgramStructurePreset = .singlePhase
    /// Total program length when using a fixed template (4/8/12/16) or the “Custom” bucket.
    var totalWeeksTemplate: TotalWeeksTemplate = .eight
    /// When `totalWeeksTemplate == .custom`, this is the total week count (1…52).
    var customTotalProgramWeeks: Int = 8
    /// When true, show per-block editors even for preset layouts (user chose “Customize phases”).
    var showPhaseCustomization: Bool = false

    private var didLoadPreferences = false

    /// Resolved total weeks from the length picker.
    var resolvedTotalProgramWeeks: Int {
        switch totalWeeksTemplate {
        case .four: return 4
        case .eight: return 8
        case .twelve: return 12
        case .sixteen: return 16
        case .custom: return min(52, max(1, customTotalProgramWeeks))
        }
    }

    init(request: DynamicProgramGenerationRequest = .simpleDefault()) {
        self.request = request
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
        state.variationModeRaw = request.splitInput.variationMode
        state.customRotationLength = request.splitInput.desiredWorkoutRotationLength
        state.variationNotes = request.splitInput.variationNotes
        state.programName = request.programName
        state.isPeriodizedProgram = request.isPeriodized
        state.busyDayPolicyRaw = request.busyDayPolicy.rawValue
        state.dynamicBlockSpecsJSON = specsJSON
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

    /// Merges a saved split preset into schedule + notes (templates still come from generation).
    func applySavedPreset(name: String, days: [SplitBuilderEditableDay], sessionsPerWeek: Int, preferredWeekdays: [Int]) {
        request.splitInput.sessionsPerWeek = min(max(1, sessionsPerWeek), 7)
        request.splitInput.preferredWeekdays = preferredWeekdays.filter { $0 >= 1 && $0 <= 7 }.sorted()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaultName = DynamicProgramGenerationRequest.simpleDefault().programName
        if request.programName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || request.programName == defaultName {
            request.programName = trimmedName.isEmpty ? defaultName : trimmedName
        }
        let dayLines = days.map { d in
            let focus = d.focus.trimmingCharacters(in: .whitespacesAndNewlines)
            return focus.isEmpty ? d.name : "\(d.name) (\(focus))"
        }.joined(separator: ", ")
        let note = "Loaded preset ‘\(name)’ — rotation ideas: \(dayLines)."
        let existing = request.splitInput.additionalNotes
        request.splitInput.additionalNotes = existing.isEmpty ? note : "\(existing)\n\(note)"
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

    func generate(aiService: AIService, dataManager: DataManager) async {
        errorMessage = nil
        isGenerating = true
        lastGenerationUsedLocalPresets = false
        defer { isGenerating = false }

        aiService.wakeProxyHostIfNeeded()

        if request.blockSpecs.count == 1 {
            request.blockSpecs[0].progressionStrategy = request.splitInput.resolvedProgressionStrategy()
        }

        let allowed = dataManager.globalExercises.map(\.name).sorted()
        let existingTemplates = dataManager.userWorkouts.map(\.name)
        let library = dataManager.globalExercises

        do {
            let program = try await aiService.generateDynamicProgram(
                request: request,
                allowedExerciseNames: allowed,
                existingWorkoutTemplateNames: existingTemplates,
                exerciseLibrary: library
            )
            generatedProgram = program
            applyErrorMessage = nil
            generationSuccessCount += 1
            lastGenerationUsedLocalPresets = !aiService.isConfigured
            editableBlockIndex = 0
            rebuildEditableDaysFromProgram()
        } catch {
            generatedProgram = nil
            perBlockEditableDays = []
            generationBalanceWarnings = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func rebuildEditableDaysFromProgram() {
        guard let prog = generatedProgram else {
            perBlockEditableDays = []
            generationBalanceWarnings = []
            return
        }
        editableBlockIndex = min(max(0, editableBlockIndex), prog.blocks.count - 1)
        perBlockEditableDays = prog.blocks.map { block in
            block.weeklyTemplates.map { t in
                SplitBuilderEditableDay(id: t.id, name: t.dayName, focus: t.focus, slots: t.slots)
            }
        }
        refreshGenerationBalanceWarnings()
    }

    /// Two-way binding for a block’s editable template days (timeline + form share this).
    func bindingForBlockDays(_ blockIndex: Int) -> Binding<[SplitBuilderEditableDay]> {
        Binding(
            get: {
                guard self.perBlockEditableDays.indices.contains(blockIndex) else { return [] }
                return self.perBlockEditableDays[blockIndex]
            },
            set: { newVal in
                guard self.perBlockEditableDays.indices.contains(blockIndex) else { return }
                self.perBlockEditableDays[blockIndex] = newVal
                self.persistPerBlockTemplatesIntoProgram()
                if blockIndex == self.editableBlockIndex {
                    self.refreshGenerationBalanceWarnings()
                }
            }
        )
    }

    func persistPerBlockTemplatesIntoProgram() {
        guard var prog = generatedProgram else { return }
        for i in prog.blocks.indices {
            guard perBlockEditableDays.indices.contains(i) else { continue }
            prog.blocks[i].weeklyTemplates = perBlockEditableDays[i].map { d in
                BlockWeeklyTemplate(id: d.id, dayName: d.name, focus: d.focus, slots: d.slots)
            }
        }
        generatedProgram = prog
    }

    /// Flattened templates for apply confirmation / conflict diff (all blocks in order).
    func flattenedEditableDaysForConfirmation() -> [SplitBuilderEditableDay] {
        perBlockEditableDays.flatMap(\.self)
    }

    func selectEditableBlock(_ index: Int) {
        persistPerBlockTemplatesIntoProgram()
        editableBlockIndex = min(max(0, index), max(0, (generatedProgram?.blocks.count ?? 1) - 1))
        refreshGenerationBalanceWarnings()
    }

    func refreshGenerationBalanceWarnings() {
        generationBalanceWarnings = balanceWarningsForBlock(at: editableBlockIndex)
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

    func applyToPlan(dataManager: DataManager, anchorDate: Date? = nil) {
        persistPerBlockTemplatesIntoProgram()
        guard let program = generatedProgram else { return }
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
        applySavedDetail = "Templates were added to your workout list and your Plan rotation matches the current program block."
        showApplySavedAlert = true
    }

    // MARK: - Private

    private static func defaultTwoBlockSpecs() -> [DynamicBlockGenerationSpec] {
        [
            DynamicBlockGenerationSpec(
                title: "Hypertrophy phase",
                focus: BlockFocus(kind: .hypertrophy, emphasisLabel: ""),
                durationWeeks: 4,
                progressionStrategy: .doubleProgression
            ),
            DynamicBlockGenerationSpec(
                title: "Strength phase",
                focus: BlockFocus(kind: .strength, emphasisLabel: ""),
                durationWeeks: 4,
                progressionStrategy: .linear
            ),
        ]
    }

}
