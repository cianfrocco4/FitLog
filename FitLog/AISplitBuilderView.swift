//
//  AISplitBuilderView.swift
//  FitLog
//
//  Wizard + preview for AI-generated workout splits (Chat Completions JSON).
//  Wizard defaults persist via SplitBuilderPreferencesStore (UserDefaults, versioned).
//

import SwiftUI

private enum SplitBuilderLimits {
    static let maxOptionalFieldChars = 400
    static let maxPriorityRecoveryChars = 400
}

private enum PrimaryTrainingGoal: String, CaseIterable, Identifiable {
    case buildMuscle = "Build muscle & size"
    case strength = "Get stronger (strength focus)"
    case fatLoss = "Fat loss / conditioning"
    case general = "General fitness & health"
    case performance = "Athletic / sport performance"

    var id: String { rawValue }
}

private enum EquipmentAccess: String, CaseIterable, Identifiable {
    case fullGym = "Full gym (machines + free weights)"
    case homeFreeWeights = "Home — barbell, dumbbells, bench"
    case dumbbellsOnly = "Home — dumbbells only"
    case bodyweight = "Mostly bodyweight"
    case minimal = "Very limited equipment"

    var id: String { rawValue }
}

private enum SplitStylePreference: String, CaseIterable, Identifiable {
    case noPreference = "No preference — you decide"
    case pushPullLegs = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case fullBody = "Full body"
    case broSplit = "Muscle group (bro) split"

    var id: String { rawValue }
}

private enum ExperiencePick: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

private enum SessionDurationPick: String, CaseIterable, Identifiable {
    case unspecified = "No preference"
    case m30 = "~30 minutes per session"
    case m45 = "~45 minutes per session"
    case m60 = "~60 minutes per session"
    case m75 = "~75 minutes per session"
    case m90 = "~90+ minutes per session"

    var id: String { rawValue }

    var minutes: Int? {
        switch self {
        case .unspecified: return nil
        case .m30: return 30
        case .m45: return 45
        case .m60: return 60
        case .m75: return 75
        case .m90: return 90
        }
    }

    static func fromStored(_ raw: String?) -> SessionDurationPick {
        guard let raw, let m = Self.allCases.first(where: { $0.rawValue == raw }) else { return .unspecified }
        return m
    }
}

private enum IntensityStylePick: String, CaseIterable, Identifiable {
    case balanced = "Balanced (mix of heavy and moderate)"
    case heavy = "Heavier loads, lower reps"
    case moderate = "Moderate loads, controlled reps (RPE ~7–8)"
    case lighterVolume = "Lighter loads, higher reps / more volume"

    var id: String { rawValue }
}

private enum ProgressionStylePick: String, CaseIterable, Identifiable {
    case linear = "Linear / add weight when form is solid"
    case doubleProgression = "Double progression (reps then weight)"
    case autoregulated = "Autoregulated (e.g. top set + back-offs)"
    case noPreference = "No preference — you decide"

    var id: String { rawValue }
}

private enum DeloadPick: String, CaseIterable, Identifiable {
    case none = "Not specified"
    case everyFourth = "Lighter week about every 4th week"
    case asNeeded = "Deload when I feel run-down"
    case manual = "I’ll manage deloads myself"

    var id: String { rawValue }
}

// MARK: - Editable proposal models

private struct EditableSlot: Identifiable {
    let id = UUID()
    var label: String
    var targetMuscleNames: [String]
    var sets: Int
    var reps: String
    var suggestedExerciseName: String?
    var suggestedExerciseOverrideId: UUID? = nil
}

private struct EditableDay: Identifiable {
    let id = UUID()
    var name: String
    var focus: String
    var slots: [EditableSlot]
}

extension EditableDay {
    init(from day: WorkoutSplitProposalDay) {
        self.name = day.name
        self.focus = day.focus ?? ""
        if !day.slots.isEmpty {
            self.slots = day.slots.map {
                EditableSlot(
                    label: $0.label,
                    targetMuscleNames: $0.targetMuscleNames,
                    sets: $0.sets,
                    reps: $0.reps,
                    suggestedExerciseName: $0.suggestedExerciseName,
                    suggestedExerciseOverrideId: $0.suggestedExerciseOverrideId
                )
            }
        } else {
            self.slots = day.exercises.map { ex in
                EditableSlot(
                    label: ex.name,
                    targetMuscleNames: ["Other"],
                    sets: ex.sets,
                    reps: ex.reps,
                    suggestedExerciseName: ex.name,
                    suggestedExerciseOverrideId: ex.libraryExerciseOverrideId
                )
            }
        }
    }
}

// MARK: - View

struct AISplitBuilderView: View {
    @EnvironmentObject private var dataVM: DataManager
    @EnvironmentObject private var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.fitlogAISplitCoachPrefill) private var coachPrefillFromEnvironment

    @State private var primaryGoal: PrimaryTrainingGoal = .general
    @State private var equipment: EquipmentAccess = .fullGym
    @State private var splitPreference: SplitStylePreference = .noPreference
    @State private var experience: ExperiencePick = .intermediate
    @State private var sessionDuration: SessionDurationPick = .unspecified
    @State private var intensityStyle: IntensityStylePick = .balanced
    @State private var progressionStyle: ProgressionStylePick = .noPreference
    @State private var limitationsNotes = ""
    @State private var additionalNotes = ""
    @State private var priorityMusclesNotes = ""
    @State private var recoveryNotes = ""
    @State private var deloadPreference: DeloadPick = .none

    @State private var sessionsPerWeek = 3
    @State private var selectedWeekdays: Set<Int> = []
    @State private var updateTrainingProgram = true

    @State private var proposal: WorkoutSplitProposal?
    @State private var editableDays: [EditableDay] = []
    @State private var originalProposal: WorkoutSplitProposal?
    @State private var isGenerating = false
    @State private var isApplying = false
    @State private var errorBanner: String?
    @State private var libraryPickContext: LibraryPickContext?
    @State private var musclePickContext: MusclePickContext?
    @State private var pendingAdjustmentInstruction: String?
    @State private var showApplySuccess = false
    @State private var applySuccessMessage = ""
    @State private var expandedDayIds: Set<UUID> = []
    @State private var exerciseSuggestContext: ExerciseSuggestContext?

    @State private var currentStep: WizardStep = .goals
    @State private var didLoadPersistedWizard = false
    @State private var didApplyCoachPrefill = false
    @State private var fullEditorWorkoutNav: FullEditorWorkoutNav?

    private struct FullEditorWorkoutNav: Identifiable, Hashable {
        let id: UUID
    }

    private enum LibraryPickContext: Identifiable {
        case slotDefault(dayId: UUID, slotId: UUID)

        var id: String {
            switch self {
            case .slotDefault(let d, let s): return "slot-\(d.uuidString)-\(s.uuidString)"
            }
        }
    }

    private enum MusclePickContext: Identifiable {
        case slot(dayId: UUID, slotId: UUID)

        var id: String {
            switch self {
            case .slot(let d, let s): return "muscle-\(d.uuidString)-\(s.uuidString)"
            }
        }
    }

    private enum ExerciseSuggestContext: Identifiable {
        case slot(dayId: UUID, slotId: UUID)

        var id: String {
            switch self {
            case .slot(let d, let s): return "exsug-\(d.uuidString)-\(s.uuidString)"
            }
        }
    }

    private var calendar: Calendar { .current }

    private enum WizardStep: Int, CaseIterable {
        case goals
        case schedule
        case details
    }

    /// When the user picks specific weekdays, cap sessions so they cannot exceed available days.
    private var maxSessionsAllowed: Int {
        if selectedWeekdays.isEmpty { return 7 }
        return max(1, selectedWeekdays.count)
    }

    private var analyzerDays: [SplitProposalProgramAnalyzer.DayInput] {
        editableDays.map { d in
            SplitProposalProgramAnalyzer.DayInput(
                name: d.name,
                focus: d.focus,
                slots: d.slots.map {
                    SplitProposalProgramAnalyzer.SlotInput(
                        label: $0.label,
                        targetMuscleNames: $0.targetMuscleNames,
                        sets: $0.sets
                    )
                }
            )
        }
    }

    private var programStats: SplitProposalProgramStats {
        SplitProposalProgramAnalyzer.stats(for: analyzerDays)
    }

    private var programWarnings: [SplitProposalProgramWarning] {
        SplitProposalProgramAnalyzer.warnings(stats: programStats, days: analyzerDays)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let p = proposal {
                    previewContent(p)
                } else {
                    wizardContent
                }
            }
            .navigationTitle(proposal == nil ? "AI split builder" : "Preview split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(item: $fullEditorWorkoutNav) { item in
                if let binding = $dataVM.userWorkouts[item.id] {
                    WorkoutPlanView(workout: binding, currentVM: currentVM)
                        .environmentObject(dataVM)
                        .environmentObject(aiService)
                } else {
                    Text("This workout is no longer in your library.")
                        .foregroundStyle(.secondary)
                        .navigationTitle("Workout")
                }
            }
        }
        .sheet(item: $libraryPickContext) { ctx in
            NavigationStack {
                SplitLibraryPickerView(exercises: dataVM.globalExercises) { ex in
                    applyLibraryPick(context: ctx, exercise: ex)
                    libraryPickContext = nil
                }
            }
        }
        .sheet(item: $musclePickContext) { ctx in
            NavigationStack {
                SplitMuscleMultiPickerView(
                    initial: musclesForContext(ctx),
                    onDone: { picked in
                        applyMusclePick(context: ctx, muscles: picked)
                        musclePickContext = nil
                    },
                    onCancel: { musclePickContext = nil }
                )
            }
        }
        .sheet(item: $exerciseSuggestContext) { ctx in
            NavigationStack {
                SplitExerciseSuggestSheet(
                    exercises: dataVM.globalExercises,
                    initialQuery: exerciseNameForContext(ctx) ?? "",
                    onPick: { ex in
                        applyExerciseSuggest(context: ctx, exercise: ex)
                        exerciseSuggestContext = nil
                    },
                    onCancel: { exerciseSuggestContext = nil }
                )
            }
        }
        .alert("Split applied", isPresented: $showApplySuccess) {
            Button("View Plan") {
                rootTabSelection?.wrappedValue = .plan
                dismiss()
            }
            Button("Done", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(applySuccessMessage)
        }
        .onAppear {
            guard !didLoadPersistedWizard else { return }
            didLoadPersistedWizard = true
            applyPersistedState(SplitBuilderPreferencesStore.load())
            if let pre = coachPrefillFromEnvironment, !pre.isEmpty, !didApplyCoachPrefill {
                didApplyCoachPrefill = true
                let block = "[Plan context]\n\(pre)\n\n"
                if additionalNotes.isEmpty {
                    additionalNotes = String(block.prefix(SplitBuilderLimits.maxOptionalFieldChars))
                } else {
                    let merged = block + additionalNotes
                    additionalNotes = String(merged.prefix(SplitBuilderLimits.maxOptionalFieldChars))
                }
            }
        }
        .onChange(of: primaryGoal) { _, _ in persistWizardState() }
        .onChange(of: equipment) { _, _ in persistWizardState() }
        .onChange(of: splitPreference) { _, _ in persistWizardState() }
        .onChange(of: experience) { _, _ in persistWizardState() }
        .onChange(of: sessionDuration) { _, _ in persistWizardState() }
        .onChange(of: intensityStyle) { _, _ in persistWizardState() }
        .onChange(of: progressionStyle) { _, _ in persistWizardState() }
        .onChange(of: deloadPreference) { _, _ in persistWizardState() }
        .onChange(of: sessionsPerWeek) { _, _ in persistWizardState() }
        .onChange(of: selectedWeekdays) { _, _ in persistWizardState() }
        .onChange(of: updateTrainingProgram) { _, _ in persistWizardState() }
        .onChange(of: limitationsNotes) { _, _ in persistWizardState() }
        .onChange(of: additionalNotes) { _, _ in persistWizardState() }
        .onChange(of: priorityMusclesNotes) { _, _ in persistWizardState() }
        .onChange(of: recoveryNotes) { _, _ in persistWizardState() }
    }

    // MARK: - Persisted wizard defaults

    private func applyPersistedState(_ s: SplitBuilderPreferencesStore.State) {
        if let r = s.primaryGoalRaw, let v = PrimaryTrainingGoal(rawValue: r) { primaryGoal = v }
        if let r = s.equipmentRaw, let v = EquipmentAccess(rawValue: r) { equipment = v }
        if let r = s.splitPreferenceRaw, let v = SplitStylePreference(rawValue: r) { splitPreference = v }
        if let r = s.experienceRaw, let v = ExperiencePick(rawValue: r) { experience = v }
        if let n = s.sessionsPerWeek { sessionsPerWeek = min(max(1, n), 7) }
        if let w = s.selectedWeekdayNumbers {
            selectedWeekdays = Set(w.filter { $0 >= 1 && $0 <= 7 })
        }
        if let u = s.updateTrainingProgram { updateTrainingProgram = u }
        if let t = s.limitationsNotes { limitationsNotes = String(t.prefix(SplitBuilderLimits.maxOptionalFieldChars)) }
        if let t = s.additionalNotes { additionalNotes = String(t.prefix(SplitBuilderLimits.maxOptionalFieldChars)) }
        sessionDuration = SessionDurationPick.fromStored(s.sessionDurationRaw)
        if let r = s.intensityStyleRaw, let v = IntensityStylePick(rawValue: r) { intensityStyle = v }
        if let r = s.progressionStyleRaw, let v = ProgressionStylePick(rawValue: r) { progressionStyle = v }
        if let t = s.priorityMusclesOrLiftsNotes {
            priorityMusclesNotes = String(t.prefix(SplitBuilderLimits.maxPriorityRecoveryChars))
        }
        if let t = s.recoveryContextNotes {
            recoveryNotes = String(t.prefix(SplitBuilderLimits.maxPriorityRecoveryChars))
        }
        if let r = s.deloadPreferenceRaw, let v = DeloadPick(rawValue: r) { deloadPreference = v }
        sessionsPerWeek = min(sessionsPerWeek, maxSessionsAllowed)
    }

    private func persistWizardState() {
        let state = SplitBuilderPreferencesStore.State(
            primaryGoalRaw: primaryGoal.rawValue,
            equipmentRaw: equipment.rawValue,
            splitPreferenceRaw: splitPreference.rawValue,
            experienceRaw: experience.rawValue,
            sessionsPerWeek: sessionsPerWeek,
            selectedWeekdayNumbers: Array(selectedWeekdays).sorted(),
            updateTrainingProgram: updateTrainingProgram,
            limitationsNotes: limitationsNotes,
            additionalNotes: additionalNotes,
            sessionDurationRaw: sessionDuration.rawValue,
            intensityStyleRaw: intensityStyle.rawValue,
            progressionStyleRaw: progressionStyle.rawValue,
            priorityMusclesOrLiftsNotes: priorityMusclesNotes,
            recoveryContextNotes: recoveryNotes,
            deloadPreferenceRaw: deloadPreference.rawValue
        )
        SplitBuilderPreferencesStore.save(state)
    }

    // MARK: - Wizard

    private var wizardContent: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.horizontal)
                .padding(.top, 8)

            TabView(selection: $currentStep) {
                goalsPage.tag(WizardStep.goals)
                schedulePage.tag(WizardStep.schedule)
                detailsPage.tag(WizardStep.details)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: currentStep)

            wizardNavigationButtons
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    private var stepIndicator: some View {
        let labels = ["Goals", "Schedule", "Details"]
        return HStack(spacing: 0) {
            ForEach(WizardStep.allCases, id: \.rawValue) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text(labels[step.rawValue])
                        .font(.caption2.weight(step == currentStep ? .semibold : .regular))
                        .foregroundStyle(step.rawValue <= currentStep.rawValue ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if step.rawValue <= currentStep.rawValue {
                        currentStep = step
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var wizardNavigationButtons: some View {
        HStack {
            if currentStep != .goals {
                Button {
                    if let prev = WizardStep(rawValue: currentStep.rawValue - 1) {
                        currentStep = prev
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep == .details {
                Button {
                    Task { await generate(adjustment: pendingAdjustmentInstruction) }
                } label: {
                    if isGenerating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Generating\u{2026}")
                        }
                    } else {
                        Label("Generate split", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!aiService.isConfigured || isGenerating)
            } else {
                Button {
                    if let next = WizardStep(rawValue: currentStep.rawValue + 1) {
                        currentStep = next
                    }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(TrailingIconLabelStyle())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Step 1: Goals

    private var goalsPage: some View {
        Form {
            if !aiService.isConfigured {
                Section { notConfiguredBanner }
            }

            Section {
                Text("You’ll get named training days with flexible exercise slots, optional default movements from your library, and—if you choose—an updated Plan calendar. Edit everything in the preview before applying.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section {
                Picker("Main goal", selection: $primaryGoal) {
                    ForEach(PrimaryTrainingGoal.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                Picker("Equipment you have", selection: $equipment) {
                    ForEach(EquipmentAccess.allCases) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                Picker("Split style", selection: $splitPreference) {
                    ForEach(SplitStylePreference.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                Picker("Experience level", selection: $experience) {
                    ForEach(ExperiencePick.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                Picker("Typical session length", selection: $sessionDuration) {
                    ForEach(SessionDurationPick.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
                Picker("Intensity style", selection: $intensityStyle) {
                    ForEach(IntensityStylePick.allCases) { i in
                        Text(i.rawValue).tag(i)
                    }
                }
                Picker("Progression style", selection: $progressionStyle) {
                    ForEach(ProgressionStylePick.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
            } header: {
                Text("Your training")
            } footer: {
                Text("Session length helps the AI keep day templates realistic. Intensity and progression shape sets and rep ranges.")
            }
        }
    }

    // MARK: - Step 2: Schedule

    private var schedulePage: some View {
        Form {
            Section {
                Stepper("Sessions per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...maxSessionsAllowed)
                weekdayMultiSelect
            } header: {
                Text("Availability")
            } footer: {
                Text("Pick preferred training days, or leave none selected for the default Mon\u{2013}Fri pool. Sessions per week cannot exceed the number of days you select.")
            }

            if !selectedWeekdays.isEmpty && sessionsPerWeek > selectedWeekdays.count {
                Section {
                    Label(
                        "You have more sessions than selected days. Reduce sessions or add days.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                    Button("Match sessions to \(selectedWeekdays.count) day\(selectedWeekdays.count == 1 ? "" : "s")") {
                        sessionsPerWeek = selectedWeekdays.count
                    }
                    .font(.caption)
                }
            }
        }
        .onChange(of: selectedWeekdays) { _, _ in
            sessionsPerWeek = min(sessionsPerWeek, maxSessionsAllowed)
        }
    }

    // MARK: - Step 3: Details + Generate

    private var detailsPage: some View {
        Form {
            Section {
                TextField(
                    "Injuries or movements to avoid",
                    text: $limitationsNotes,
                    prompt: Text("e.g. sore shoulder — limit overhead pressing"),
                    axis: .vertical
                )
                .lineLimit(2...4)
                TextField(
                    "Priority muscles or lifts",
                    text: $priorityMusclesNotes,
                    prompt: Text("e.g. bring up glutes and back thickness"),
                    axis: .vertical
                )
                .lineLimit(2...4)
                TextField(
                    "Recovery / other stress",
                    text: $recoveryNotes,
                    prompt: Text("e.g. two soccer practices / week, average sleep"),
                    axis: .vertical
                )
                .lineLimit(2...4)
                TextField(
                    "Anything else we should know?",
                    text: $additionalNotes,
                    prompt: Text("e.g. prefer short warm-ups, no machines"),
                    axis: .vertical
                )
                .lineLimit(2...4)
            } header: {
                Text("Optional details")
            } footer: {
                Text("Up to \(SplitBuilderLimits.maxOptionalFieldChars) characters per field. Not medical advice.")
            }

            Section {
                Picker("Deload preference", selection: $deloadPreference) {
                    ForEach(DeloadPick.allCases) { d in
                        Text(d.rawValue).tag(d)
                    }
                }
            }

            Section {
                Toggle("Set as my training program", isOn: $updateTrainingProgram)
                Text("When on, your Plan cycle and weekly schedule update to this split. When off, only new workout templates are created.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let err = errorBanner {
                Section {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .onChange(of: limitationsNotes) { _, new in
            if new.count > SplitBuilderLimits.maxOptionalFieldChars {
                limitationsNotes = String(new.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            }
        }
        .onChange(of: additionalNotes) { _, new in
            if new.count > SplitBuilderLimits.maxOptionalFieldChars {
                additionalNotes = String(new.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            }
        }
        .onChange(of: priorityMusclesNotes) { _, new in
            if new.count > SplitBuilderLimits.maxPriorityRecoveryChars {
                priorityMusclesNotes = String(new.prefix(SplitBuilderLimits.maxPriorityRecoveryChars))
            }
        }
        .onChange(of: recoveryNotes) { _, new in
            if new.count > SplitBuilderLimits.maxPriorityRecoveryChars {
                recoveryNotes = String(new.prefix(SplitBuilderLimits.maxPriorityRecoveryChars))
            }
        }
        .keyboardDismissToolbar()
    }

    private var libraryApplyStats: (newCustom: Int, libraryLinks: Int) {
        var newCustom = 0
        var libraryLinks = 0
        for day in editableDays {
            for slot in day.slots {
                if let oid = slot.suggestedExerciseOverrideId,
                   dataVM.globalExercises.contains(where: { $0.id == oid }) {
                    libraryLinks += 1
                    continue
                }
                let raw = (slot.suggestedExerciseName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { continue }
                guard let r = ExerciseNameResolution.resolve(planName: raw, library: dataVM.globalExercises) else { continue }
                switch r {
                case .linked: libraryLinks += 1
                case .createCustom: newCustom += 1
                }
            }
        }
        return (newCustom, libraryLinks)
    }

    private func applyLibraryPick(context: LibraryPickContext, exercise: Exercise) {
        switch context {
        case .slotDefault(let dayId, let slotId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
            editableDays[dIdx].slots[sIdx].suggestedExerciseOverrideId = exercise.id
            editableDays[dIdx].slots[sIdx].suggestedExerciseName = exercise.name
        }
    }

    private func musclesForContext(_ ctx: MusclePickContext) -> [MuscleGroup] {
        switch ctx {
        case .slot(let dayId, let slotId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return [] }
            let parsed = ExerciseNameResolution.resolveMuscleGroups(from: editableDays[dIdx].slots[sIdx].targetMuscleNames)
            return parsed.isEmpty ? [] : parsed
        }
    }

    private func exerciseNameForContext(_ ctx: ExerciseSuggestContext) -> String? {
        switch ctx {
        case .slot(let dayId, let slotId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return nil }
            return editableDays[dIdx].slots[sIdx].suggestedExerciseName
        }
    }

    private func applyMusclePick(context: MusclePickContext, muscles: [MuscleGroup]) {
        switch context {
        case .slot(let dayId, let slotId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
            editableDays[dIdx].slots[sIdx].targetMuscleNames = muscles.map(\.rawValue)
        }
    }

    private func applyExerciseSuggest(context: ExerciseSuggestContext, exercise: Exercise) {
        switch context {
        case .slot(let dayId, let slotId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
            editableDays[dIdx].slots[sIdx].suggestedExerciseName = exercise.name
            editableDays[dIdx].slots[sIdx].suggestedExerciseOverrideId = exercise.id
        }
    }

    private func slotMuscleOutcomeLine(_ slot: EditableSlot) -> String {
        let parsed = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
        if !parsed.isEmpty {
            return "Targets: \(parsed.map(\.rawValue).joined(separator: ", "))."
        }
        let tokens = slot.targetMuscleNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if tokens.isEmpty {
            return "Tap “Muscles” to pick target groups, or Other is used."
        }
        return "Some muscle labels didn’t match known groups; Other is used where needed."
    }

    private func slotSuggestedExerciseLine(_ slot: EditableSlot) -> String {
        if let oid = slot.suggestedExerciseOverrideId,
           let ex = dataVM.globalExercises.first(where: { $0.id == oid }) {
            return "Default exercise: \(ex.name) (your pick)."
        }
        let raw = (slot.suggestedExerciseName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "Open slot — you’ll choose an exercise in this category each time you start the workout."
        }
        guard let r = ExerciseNameResolution.resolve(planName: raw, library: dataVM.globalExercises) else {
            return ""
        }
        switch r {
        case .linked(let ex):
            if ExerciseNameResolution.normalizationKey(raw) != ExerciseNameResolution.normalizationKey(ex.name) {
                return "Default exercise: \(ex.name) (matched from your text)."
            }
            return "Default exercise: \(ex.name)."
        case .createCustom(let name):
            return "Adds “\(name)” as a custom exercise and uses it as the default."
        }
    }

    private func compareProgramSummaryLines() -> [String] {
        var lines: [String] = []
        let cycle = dataVM.trainingProgram.cycleEntries
        lines.append("Current program cycle: \(cycle.count) day\(cycle.count == 1 ? "" : "s") in rotation.")
        if !cycle.isEmpty {
            let names = cycle.prefix(8).map { dataVM.planLabel(for: $0) }
            lines.append("Current cycle: \(names.joined(separator: " → "))\(cycle.count > 8 ? " …" : "")")
        }
        lines.append("This proposal: \(editableDays.count) new workout template\(editableDays.count == 1 ? "" : "s").")
        if updateTrainingProgram {
            lines.append("Applying will replace your training program cycle with these templates (library entries are added; existing templates stay unless you remove them later).")
        } else {
            lines.append("Applying adds templates only; your Plan calendar cycle stays as-is until you change it.")
        }
        return lines
    }

    private func previewContent(_ p: WorkoutSplitProposal) -> some View {
        List {
            previewSummarySection(p)
            previewProgramSnapshotSection
            previewBalanceSection
            previewCompareSection
            regenerateTweaksSection
            libraryChangesSection
            previewEditableDaysSection
            previewApplySection
        }
        .environment(\.editMode, .constant(.active))
        .onAppear {
            if expandedDayIds.isEmpty {
                expandedDayIds = Set(editableDays.map(\.id))
            }
        }
    }

    @ViewBuilder
    private func previewSummarySection(_ p: WorkoutSplitProposal) -> some View {
        Section {
            Text(p.rationale)
                .font(.subheadline)
            LabeledContent("Sessions / week", value: "\(p.sessionsPerWeek)")
            if p.preferredWeekdays.isEmpty {
                LabeledContent("Preferred days", value: "Default (Mon\u{2013}Fri pool)")
            } else {
                LabeledContent("Preferred days", value: p.preferredWeekdays.map { weekdayLabel($0) }.joined(separator: ", "))
            }
        } header: {
            Text("Summary")
        }
    }

    private var previewProgramSnapshotSection: some View {
        Section {
            LabeledContent("Weekly sets (all slots)", value: "\(programStats.totalHardSetsPerWeek)")
            LabeledContent("Split style", value: programStats.inferredSplitStyle)
            LabeledContent("Muscle tags used", value: "\(programStats.distinctMuscleGroupsTouched)")
            let rough = "\(programStats.pushOrientedSets) / \(programStats.pullOrientedSets) / \(programStats.legOrientedSets)"
            LabeledContent("Push / pull / leg emphasis (rough)", value: "\(rough) set·muscle hits")
            let legKneeHinge = "\(programStats.quadKneeOrientedSets) / \(programStats.hipPosteriorLegSets)"
            LabeledContent("Leg: knee vs hinge / posterior (rough)", value: "\(legKneeHinge) set·muscle hits")
        } header: {
            Text("Program snapshot")
        } footer: {
            Text("Set·muscle hits are coarse (any split). Compare push vs pull totals and knee vs hinge leg work for balance.")
        }
    }

    @ViewBuilder
    private var previewBalanceSection: some View {
        if !programWarnings.isEmpty {
            Section {
                ForEach(programWarnings) { w in
                    Label(w.message, systemImage: w.severity == .caution ? "exclamationmark.triangle.fill" : "info.circle")
                        .font(.caption)
                        .foregroundStyle(w.severity == .caution ? Color.orange : Color.secondary)
                }
            } header: {
                Text("Balance checks")
            }
        }
    }

    private var previewCompareSection: some View {
        Section {
            ForEach(compareProgramSummaryLines(), id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Compared to now")
        }
    }

    private var previewEditableDaysSection: some View {
        ForEach(editableDays) { day in
            Section {
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedDayIds.contains(day.id) },
                    set: { on in
                        if on { expandedDayIds.insert(day.id) } else { expandedDayIds.remove(day.id) }
                    }
                )) {
                    dayEditorContent(day: bindingForEditableDay(id: day.id))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name.isEmpty ? "Untitled day" : day.name)
                            .font(.headline)
                        Text("\(day.slots.count) slot\(day.slots.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onMove { from, to in editableDays.move(fromOffsets: from, toOffset: to) }
    }

    private func bindingForEditableDay(id: UUID) -> Binding<EditableDay> {
        Binding(
            get: {
                editableDays.first(where: { $0.id == id })!
            },
            set: { new in
                guard let i = editableDays.firstIndex(where: { $0.id == id }) else { return }
                editableDays[i] = new
            }
        )
    }

    private var previewApplySection: some View {
        Section {
            Toggle("Set as my training program", isOn: $updateTrainingProgram)

            Button {
                let final = buildProposalFromEdits()
                Task { await apply(final) }
            } label: {
                if isApplying {
                    HStack {
                        ProgressView()
                        Text("Applying\u{2026}")
                    }
                } else {
                    Label("Apply split", systemImage: "checkmark.circle.fill")
                }
            }
            .disabled(isApplying)

            Button("Regenerate") {
                pendingAdjustmentInstruction = nil
                proposal = nil
                originalProposal = nil
                editableDays = []
                expandedDayIds = []
                errorBanner = nil
            }

            if let orig = originalProposal {
                Button("Undo all edits", role: .destructive) {
                    editableDays = orig.workouts.map { EditableDay(from: $0) }
                }
            }
        }
    }

    @ViewBuilder
    private func dayEditorContent(day: Binding<EditableDay>) -> some View {
        TextField("Day name", text: day.name)
            .font(.headline)
        TextField("Focus", text: day.focus)
            .font(.caption)
            .foregroundStyle(.secondary)

        Text("Each row is a slot. Set a default exercise to pre-fill that movement, or leave it blank for an open slot.")
            .font(.caption)
            .foregroundStyle(.secondary)

        ForEach(day.slots) { $slot in
            editableSlotRow(dayId: day.wrappedValue.id, slot: $slot)
        }
        .onDelete { indices in
            var d = day.wrappedValue
            d.slots.remove(atOffsets: indices)
            day.wrappedValue = d
        }
        .onMove { from, to in
            var d = day.wrappedValue
            d.slots.move(fromOffsets: from, toOffset: to)
            day.wrappedValue = d
        }

        Button {
            var d = day.wrappedValue
            d.slots.append(
                EditableSlot(label: "New slot", targetMuscleNames: [MuscleGroup.other.rawValue], sets: 3, reps: "8-12", suggestedExerciseName: nil)
            )
            day.wrappedValue = d
        } label: {
            Label("Add slot", systemImage: "plus.circle")
                .font(.subheadline)
        }

        Button {
            let newId = createLibraryWorkoutFromPreviewDay(day.wrappedValue)
            fullEditorWorkoutNav = FullEditorWorkoutNav(id: newId)
        } label: {
            Label("Open in full workout editor", systemImage: "rectangle.and.pencil.and.ellipsis")
        }
        .font(.subheadline)
        .padding(.top, 4)
    }

    /// Copies preview day into a new library workout for editing in `WorkoutPlanView` (does not apply the split).
    private func createLibraryWorkoutFromPreviewDay(_ day: EditableDay) -> UUID {
        let trimmed = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Workout" : trimmed
        let name = dataVM.uniqueWorkoutName(base)
        let workoutId = dataVM.createWorkout(name: name)
        for slot in day.slots {
            let muscles = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
            var ex: Exercise?
            if let oid = slot.suggestedExerciseOverrideId {
                ex = dataVM.globalExercises.first(where: { $0.id == oid })
            }
            if ex == nil {
                let raw = (slot.suggestedExerciseName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty, let r = ExerciseNameResolution.resolve(planName: raw, library: dataVM.globalExercises) {
                    switch r {
                    case .linked(let e):
                        ex = e
                    case .createCustom(let dn):
                        let m = muscles.isEmpty ? [MuscleGroup.other] : muscles
                        ex = dataVM.addNewExercise(name: dn, description: "", muscles: m)
                    }
                }
            }
            let sets = min(max(1, slot.sets), 10)
            let reps = slot.reps.trimmingCharacters(in: .whitespacesAndNewlines)
            let repsFinal = reps.isEmpty ? "8-12" : reps
            if let ex, let w = dataVM.workout(id: workoutId) {
                _ = dataVM.addExercise(
                    to: w,
                    exercise: ex,
                    recommendedSets: sets,
                    recommendedReps: repsFinal,
                    configurationFields: [],
                    recommendedConfigBySet: Array(repeating: [:], count: sets)
                )
            } else {
                let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Slot" : slot.label
                let ts = TemplateSlot(
                    label: label,
                    targetedMuscles: muscles.isEmpty ? [.other] : muscles,
                    exerciseRole: nil,
                    movementPattern: nil,
                    defaultExerciseId: nil,
                    defaultRestTime: 90,
                    recommendedSets: sets,
                    recommendedReps: repsFinal
                )
                _ = dataVM.appendFlexibleSlot(toWorkoutId: workoutId, slot: ts)
            }
        }
        return workoutId
    }

    private var regenerateTweaksSection: some View {
        Section {
            Text("Regenerate keeps your wizard answers and asks the model for a different flavor.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                regenerate(with: RegenerateTweak.shorter)
            } label: {
                Label("Shorter sessions", systemImage: "clock")
            }
            Button {
                regenerate(with: RegenerateTweak.moreCompounds)
            } label: {
                Label("More compounds", systemImage: "figure.strengthtraining.traditional")
            }
            Button {
                regenerate(with: RegenerateTweak.lessVolume)
            } label: {
                Label("Less volume", systemImage: "minus.circle")
            }
        } header: {
            Text("Try another version")
        }
    }

    private enum RegenerateTweak {
        case shorter, moreCompounds, lessVolume

        var instruction: String {
            switch self {
            case .shorter:
                return "Regenerate the split prioritizing shorter sessions: fewer slots and/or fewer sets per day while preserving the user’s goals, equipment, and split preference."
            case .moreCompounds:
                return "Regenerate with more emphasis on big compound movements early each day; trim isolation accessories where possible."
            case .lessVolume:
                return "Regenerate with roughly 15–25% less weekly volume (fewer sets or fewer slots) while keeping the same structure intent."
            }
        }
    }

    private func regenerate(with tweak: RegenerateTweak) {
        pendingAdjustmentInstruction = tweak.instruction
        proposal = nil
        originalProposal = nil
        editableDays = []
        expandedDayIds = []
        errorBanner = nil
        Task { await generate(adjustment: tweak.instruction) }
    }

    // MARK: - Preview row helpers

    private func editableSlotRow(dayId: UUID, slot: Binding<EditableSlot>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Slot label", text: slot.label)
                .font(.body)

            muscleSummaryRow(dayId: dayId, slot: slot)

            Text(slotMuscleOutcomeLine(slot.wrappedValue))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Compound preset") {
                    applySlotPreset(.compound, dayId: dayId, slotId: slot.wrappedValue.id)
                }
                .font(.caption2)
                Button("Accessory") {
                    applySlotPreset(.accessory, dayId: dayId, slotId: slot.wrappedValue.id)
                }
                .font(.caption2)
                Button("Isolation") {
                    applySlotPreset(.isolation, dayId: dayId, slotId: slot.wrappedValue.id)
                }
                .font(.caption2)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 12) {
                Stepper("Sets: \(slot.wrappedValue.sets)", value: slot.sets, in: 1...10)
                    .font(.caption)
                TextField("Reps", text: slot.reps)
                    .font(.caption)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(alignment: .firstTextBaseline) {
                TextField("Default exercise (optional)", text: Binding(
                    get: { slot.wrappedValue.suggestedExerciseName ?? "" },
                    set: {
                        slot.wrappedValue.suggestedExerciseName = $0.isEmpty ? nil : $0
                        if $0.isEmpty { slot.wrappedValue.suggestedExerciseOverrideId = nil }
                    }
                ))
                .font(.caption2)
                .textFieldStyle(.roundedBorder)

                Button {
                    exerciseSuggestContext = .slot(dayId: dayId, slotId: slot.wrappedValue.id)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search library for default exercise")
            }

            Text(slotSuggestedExerciseLine(slot.wrappedValue))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Pick from library") {
                    libraryPickContext = .slotDefault(dayId: dayId, slotId: slot.wrappedValue.id)
                }
                .font(.caption)
                if slot.wrappedValue.suggestedExerciseOverrideId != nil {
                    Button("Clear pick") {
                        slot.suggestedExerciseOverrideId.wrappedValue = nil
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func muscleSummaryRow(dayId: UUID, slot: Binding<EditableSlot>) -> some View {
        let names = ExerciseNameResolution.resolveMuscleGroups(from: slot.wrappedValue.targetMuscleNames).map(\.rawValue)
        let summary = names.isEmpty ? "No muscles selected" : names.joined(separator: ", ")
        return HStack {
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Muscles") {
                musclePickContext = .slot(dayId: dayId, slotId: slot.wrappedValue.id)
            }
            .font(.caption)
        }
    }

    private enum SlotPresetKind {
        case compound, accessory, isolation
    }

    private func applySlotPreset(_ kind: SlotPresetKind, dayId: UUID, slotId: UUID) {
        guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
              let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
        switch kind {
        case .compound:
            editableDays[dIdx].slots[sIdx].sets = max(editableDays[dIdx].slots[sIdx].sets, 4)
            editableDays[dIdx].slots[sIdx].reps = "6-8"
        case .accessory:
            editableDays[dIdx].slots[sIdx].sets = min(max(editableDays[dIdx].slots[sIdx].sets, 3), 4)
            editableDays[dIdx].slots[sIdx].reps = "10-15"
        case .isolation:
            editableDays[dIdx].slots[sIdx].sets = 3
            editableDays[dIdx].slots[sIdx].reps = "12-20"
        }
    }

    private var libraryChangesSection: some View {
        let stats = libraryApplyStats
        return Section {
            Text("When you apply, names are matched to your library (including small typos and spacing). Anything that still doesn’t match is added as a custom exercise so rows aren’t dropped.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if stats.libraryLinks > 0 {
                LabeledContent("Rows using your library", value: "\(stats.libraryLinks)")
            }
            if stats.newCustom > 0 {
                LabeledContent("New custom exercises", value: "\(stats.newCustom)")
            }
        } header: {
            Text("Library")
        }
    }

    private var notConfiguredBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI not configured", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text("Add OPENAI_API_KEY or FITLOG_AI_BASE_URL in your Xcode scheme or Info.plist. See OPENAI_SETUP.md in the project.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var weekdayMultiSelect: some View {
        let days: [(Int, String)] = [
            (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
            (5, "Thu"), (6, "Fri"), (7, "Sat")
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
            ForEach(days, id: \.0) { wd, label in
                let on = selectedWeekdays.contains(wd)
                Button {
                    if on { selectedWeekdays.remove(wd) } else { selectedWeekdays.insert(wd) }
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "\(weekday)" }
        return symbols[weekday - 1]
    }

    private func structuredInput(adjustment: String?) -> WorkoutSplitBuilderStructuredInput {
        WorkoutSplitBuilderStructuredInput(
            primaryGoal: primaryGoal.rawValue,
            equipment: equipment.rawValue,
            splitPreference: splitPreference.rawValue,
            experienceLevel: experience.rawValue,
            sessionsPerWeek: sessionsPerWeek,
            preferredWeekdays: Array(selectedWeekdays).sorted(),
            limitationsNotes: limitationsNotes,
            additionalNotes: additionalNotes,
            sessionDurationMinutes: sessionDuration.minutes,
            intensityStyle: intensityStyle.rawValue,
            progressionStyle: progressionStyle.rawValue,
            priorityMusclesOrLiftsNotes: priorityMusclesNotes,
            recoveryContextNotes: recoveryNotes,
            deloadPreference: deloadPreference.rawValue,
            adjustmentInstruction: adjustment
        )
    }

    @MainActor
    private func generate(adjustment: String?) async {
        errorBanner = nil
        isGenerating = true
        defer {
            isGenerating = false
            pendingAdjustmentInstruction = nil
        }

        aiService.wakeProxyHostIfNeeded()

        let allowed = dataVM.globalExercises.map(\.name).sorted()
        let existingTemplates = dataVM.userWorkouts.map(\.name)
        let structured = structuredInput(adjustment: adjustment)

        do {
            let result = try await aiService.generateWorkoutSplitProposal(
                structured: structured,
                allowedExerciseNames: allowed,
                existingWorkoutTemplateNames: existingTemplates
            )
            proposal = result
            originalProposal = result
            editableDays = result.workouts.map { EditableDay(from: $0) }
            expandedDayIds = Set(editableDays.map(\.id))
        } catch {
            errorBanner = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func buildProposalFromEdits() -> WorkoutSplitProposal {
        let days = editableDays.map { day -> WorkoutSplitProposalDay in
            let slots = day.slots.map {
                WorkoutSplitProposalSlotItem(
                    label: $0.label,
                    targetMuscleNames: $0.targetMuscleNames,
                    sets: $0.sets,
                    reps: $0.reps,
                    suggestedExerciseName: $0.suggestedExerciseName,
                    suggestedExerciseOverrideId: $0.suggestedExerciseOverrideId
                )
            }
            return WorkoutSplitProposalDay(
                name: day.name,
                focus: day.focus.isEmpty ? nil : day.focus,
                exercises: [],
                slots: slots
            )
        }
        return WorkoutSplitProposal(
            rationale: proposal?.rationale ?? "",
            sessionsPerWeek: proposal?.sessionsPerWeek ?? sessionsPerWeek,
            preferredWeekdays: proposal?.preferredWeekdays ?? Array(selectedWeekdays).sorted(),
            workouts: days
        )
    }

    @MainActor
    private func apply(_ p: WorkoutSplitProposal) async {
        isApplying = true
        defer { isApplying = false }

        dataVM.applyWorkoutSplitProposal(
            p,
            updateTrainingProgram: updateTrainingProgram,
            anchorDate: Date()
        )

        let templates = p.workouts.count
        let planLine = updateTrainingProgram
            ? "Your Plan tab now follows this cycle."
            : "Your Plan calendar was not changed; new templates are in your workout list."
        applySuccessMessage = "Created \(templates) workout template\(templates == 1 ? "" : "s"). \(planLine)"
        showApplySuccess = true
    }
}

// MARK: - Muscle picker

private struct SplitMuscleMultiPickerView: View {
    let initial: [MuscleGroup]
    let onDone: ([MuscleGroup]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<MuscleGroup> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("Choose 1–3 groups for this slot (first = primary emphasis in the app).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(MuscleGroup.displayOrder, id: \.self) { m in
                let on = selected.contains(m)
                Button {
                    if on {
                        selected.remove(m)
                    } else if selected.count < 3 {
                        selected.insert(m)
                    }
                } label: {
                    HStack {
                        Text(m.rawValue)
                        Spacer()
                        if on { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint) }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Target muscles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    let arr = MuscleGroup.displayOrder.filter { selected.contains($0) }
                    onDone(arr.isEmpty ? [.other] : arr)
                    dismiss()
                }
            }
        }
        .onAppear {
            selected = Set(initial.isEmpty ? [.other] : initial)
        }
    }
}

// MARK: - Exercise search sheet

private struct SplitExerciseSuggestSheet: View {
    let exercises: [Exercise]
    let initialQuery: String
    let onPick: (Exercise) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var sorted: [Exercise] {
        exercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filtered: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(sorted.prefix(80)) }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }.prefix(80).map { $0 }
    }

    var body: some View {
        List(filtered) { ex in
            Button {
                onPick(ex)
                dismiss()
            } label: {
                Text(ex.name)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Default exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
            }
        }
        .onAppear {
            searchText = initialQuery
        }
    }
}

private struct SplitLibraryPickerView: View {
    let exercises: [Exercise]
    let onSelect: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Exercise] {
        let sorted = exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List(filtered) { ex in
            Button {
                onSelect(ex)
                dismiss()
            } label: {
                Text(ex.name)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Link exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

