//
//  DynamicProgramBuilderView.swift
//  FitLog
//
//  Streamlined 3-step wizard for dynamic / periodized programs (AI or manual).
//

import SwiftData
import SwiftUI

// MARK: - Wizard pickers

private enum DPGoalPick: String, CaseIterable, Identifiable {
    case buildMuscle = "Build muscle & size"
    case strength = "Get stronger (strength focus)"
    case fatLoss = "Fat loss / conditioning"
    case general = "General fitness & health"
    case performance = "Athletic / sport performance"
    var id: String { rawValue }
}

private enum DPEquipmentPick: String, CaseIterable, Identifiable {
    case fullGym = "Full gym (machines + free weights)"
    case homeFreeWeights = "Home — barbell, dumbbells, bench"
    case dumbbellsOnly = "Home — dumbbells only"
    case bodyweight = "Mostly bodyweight"
    case minimal = "Very limited equipment"
    var id: String { rawValue }
}

private enum DPSplitPick: String, CaseIterable, Identifiable {
    case noPreference = "No preference — you decide"
    case pushPullLegs = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case fullBody = "Full body"
    case broSplit = "Muscle group (bro) split"
    var id: String { rawValue }
}

private enum DPExperiencePick: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: String { rawValue }
}

private enum DPSessionDurationPick: String, CaseIterable, Identifiable {
    case unspecified = "No preference"
    case m30 = "~30 minutes per session"
    case m45 = "~45 minutes per session"
    case m60 = "~60 minutes per session"
    case m75 = "~75 minutes per session"
    case m90 = "~90+ minutes per session"
    var id: String { rawValue }
}

private enum DPIntensityPick: String, CaseIterable, Identifiable {
    case balanced = "Balanced (mix of heavy and moderate)"
    case heavy = "Heavier loads, lower reps"
    case moderate = "Moderate loads, controlled reps (RPE ~7–8)"
    case lighterVolume = "Lighter loads, higher reps / more volume"
    var id: String { rawValue }
}

private enum DPProgressionPick: String, CaseIterable, Identifiable {
    case linear = "Linear / add weight when form is solid"
    case doubleProgression = "Double progression (reps then weight)"
    case autoregulated = "Autoregulated (e.g. top set + back-offs)"
    case noPreference = "No preference — you decide"
    var id: String { rawValue }
}

private enum DPDeloadPick: String, CaseIterable, Identifiable {
    case none = "Not specified"
    case everyFourth = "Lighter week about every 4th week"
    case asNeeded = "Deload when I feel run-down"
    case manual = "I’ll manage deloads myself"
    var id: String { rawValue }
}

// MARK: - View

struct DynamicProgramBuilderView: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @EnvironmentObject private var aiService: AIService
    @Environment(DataManager.self) private var dataManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @State private var confirmClearDynamicProgram = false
    @State private var showApplyReviewSheet = false
    @State private var showSavedPresetBrowser = false

    private var calendar: Calendar { .current }

    private var maxSessionsAllowed: Int {
        let sel = Set(viewModel.request.splitInput.preferredWeekdays.filter { $0 >= 1 && $0 <= 7 })
        if sel.isEmpty { return 7 }
        return max(1, sel.count)
    }

    private var builderModeHelp: String {
        switch viewModel.builderMode {
        case .aiGenerate:
            return "AI (when configured) or local presets draft your rotation. Everything stays editable before you save to Plan."
        case .manualBuild:
            return "Creates a blank rotation from your schedule so you can add exercises without calling AI."
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                wizardStepIndicator
                    .padding(.horizontal)
                    .padding(.top, 8)

                TabView(selection: $viewModel.wizardStep) {
                    essentialsStep.tag(DynamicProgramBuilderViewModel.WizardStep.essentials)
                    structureStep.tag(DynamicProgramBuilderViewModel.WizardStep.structure)
                    reviewAndEditStep.tag(DynamicProgramBuilderViewModel.WizardStep.reviewAndEdit)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.22), value: viewModel.wizardStep)

                if viewModel.wizardStep != .reviewAndEdit {
                    livePreviewChip
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                wizardChromeBar
                    .padding(.horizontal)
                    .padding(.bottom, viewModel.wizardStep == .reviewAndEdit ? 72 : 8)
            }

            if viewModel.wizardStep == .reviewAndEdit {
                ProgramBuilderFloatingActionBar(
                    summaryLine: viewModel.liveSummaryLine,
                    validationResult: viewModel.programValidationResult,
                    primaryTitle: viewModel.generatedProgram == nil
                        ? (viewModel.builderMode == .aiGenerate ? "Generate" : "Create draft")
                        : "Save to Plan",
                    isPrimaryDisabled: reviewPrimaryDisabled,
                    isLoading: viewModel.isGenerating || viewModel.isConnectingToProxy || viewModel.isApplying,
                    onPrimary: handleReviewPrimaryAction
                )
            }
        }
        .navigationTitle("Custom build")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSavedPresetBrowser = true
                } label: {
                    Label("Saved preset", systemImage: "square.stack.3d.up")
                }
                .accessibilityLabel("Load saved preset")
            }
            if dataManager.dynamicProgramState != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        confirmClearDynamicProgram = true
                    }
                    .accessibilityLabel("Clear dynamic program")
                }
            }
        }
        .sheet(isPresented: $showSavedPresetBrowser) {
            SplitPresetBrowser { name, days, sessions, weekdays in
                viewModel.applySavedPreset(name: name, days: days, sessionsPerWeek: sessions, preferredWeekdays: weekdays)
                showSavedPresetBrowser = false
            }
            .environment(dataManager)
            .environment(\.modelContext, modelContext)
        }
        .confirmationDialog(
            "Stop using this dynamic program?",
            isPresented: $confirmClearDynamicProgram,
            titleVisibility: .visible
        ) {
            Button("Remove from plan", role: .destructive) {
                dataManager.setDynamicProgramState(nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workout templates stay in your library. The Plan tab will follow your training program rotation again.")
        }
        .sensoryFeedback(.success, trigger: viewModel.generationSuccessCount)
        .sensoryFeedback(.success, trigger: viewModel.applySuccessCount)
        .alert("Saved to plan", isPresented: $viewModel.showApplySavedAlert) {
            Button("View Plan") { rootTabSelection?.wrappedValue = .plan }
            Button("Done", role: .cancel) { dismiss() }
        } message: {
            Text(viewModel.applySavedDetail)
        }
        .sheet(isPresented: $showApplyReviewSheet) {
            if let prog = viewModel.generatedProgram {
                SplitApplyConfirmationView(
                    days: viewModel.flattenedEditableDaysForConfirmation(),
                    sessionsPerWeek: prog.defaultSessionsPerWeek,
                    preferredWeekdays: prog.preferredWeekdays,
                    rationale: viewModel.lastGenerationUsedLocalPresets
                        ? "Local preset dynamic program."
                        : "AI-generated dynamic program.",
                    updateTrainingProgram: true,
                    dataVM: dataManager,
                    onConfirm: { anchor in
                        viewModel.applyToPlan(dataManager: dataManager, anchorDate: anchor)
                        showApplyReviewSheet = false
                    },
                    onCancel: { showApplyReviewSheet = false }
                )
            }
        }
        .onAppear {
            viewModel.bootstrapFromContext(dataManager: dataManager)
        }
        .onDisappear {
            viewModel.persistPreferencesToStore()
        }
        .onChange(of: viewModel.builderMode) { _, _ in
            viewModel.builderModeChangeCount += 1
            viewModel.persistPreferencesToStore()
            if viewModel.wizardStep == .reviewAndEdit {
                viewModel.ensureManualDraftIfNeeded()
            }
        }
        .onChange(of: viewModel.wizardStep) { _, newStep in
            if newStep == .reviewAndEdit {
                viewModel.ensureManualDraftIfNeeded()
            }
        }
        .onChange(of: viewModel.request.splitInput.experienceLevel) { _, _ in
            viewModel.applyExperienceBasedDefaults()
        }
        .sensoryFeedback(.selection, trigger: viewModel.builderModeChangeCount)
    }

    // MARK: - Step chrome

    private var wizardStepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(DynamicProgramBuilderViewModel.WizardStep.allCases) { step in
                VStack(spacing: 4) {
                    Circle()
                        .fill(step.rawValue <= viewModel.wizardStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(step == viewModel.wizardStep ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wizard step \(viewModel.wizardStep.title)")
    }

    private var livePreviewChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FitlogPalette.chartPrimary)
            Text(viewModel.liveSummaryLine)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
        .accessibilityLabel("Program preview: \(viewModel.liveSummaryLine)")
    }

    private var wizardChromeBar: some View {
        HStack {
            Button("Back") {
                if let prev = DynamicProgramBuilderViewModel.WizardStep(rawValue: viewModel.wizardStep.rawValue - 1) {
                    viewModel.wizardStep = prev
                }
            }
            .disabled(viewModel.wizardStep == .essentials)
            .accessibilityHint("Go to previous step")

            Spacer()

            if viewModel.wizardStep != .reviewAndEdit {
                Button("Next") {
                    if let next = DynamicProgramBuilderViewModel.WizardStep(rawValue: viewModel.wizardStep.rawValue + 1) {
                        viewModel.wizardStep = next
                    }
                }
                .fontWeight(.semibold)
                .accessibilityHint("Go to next step")
            }
        }
    }

    // MARK: - Step 1 — Essentials

    private var essentialsStep: some View {
        Form {
            Section {
                Picker("Program build style", selection: $viewModel.builderMode) {
                    ForEach(DynamicProgramBuilderViewModel.ProgramBuilderMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(builderModeHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Builder")
            }

            Section("Essentials") {
                TextField("Program name", text: $viewModel.request.programName)
                    .textInputAutocapitalization(.words)

                Picker("Primary goal", selection: goalBinding) {
                    ForEach(DPGoalPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }

                Picker("Equipment", selection: equipmentBinding) {
                    ForEach(DPEquipmentPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }

                Picker("Experience", selection: experienceBinding) {
                    ForEach(DPExperiencePick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }

                Stepper(value: Binding(
                    get: { viewModel.request.splitInput.sessionsPerWeek },
                    set: { viewModel.request.splitInput.sessionsPerWeek = min(max(1, $0), maxSessionsAllowed) }
                ), in: 1 ... maxSessionsAllowed) {
                    Text("Sessions per week: \(viewModel.request.splitInput.sessionsPerWeek)")
                }
            }

            Section("Preferred training days") {
                Text("Leave none selected to use weekdays Mon–Fri as the scheduling pool.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                weekdayPickGrid
            }
        }
    }

    // MARK: - Step 2 — Structure

    private var structureStep: some View {
        Form {
            Section("Length & split") {
                Picker("Program length", selection: $viewModel.totalWeeksTemplate) {
                    ForEach(DynamicProgramBuilderViewModel.TotalWeeksTemplate.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }

                if viewModel.totalWeeksTemplate == .custom {
                    Stepper(value: $viewModel.customTotalProgramWeeks, in: 1 ... 52) {
                        Text("Total: \(viewModel.customTotalProgramWeeks) weeks")
                    }
                }

                Picker("Split style", selection: splitBinding) {
                    ForEach(DPSplitPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }

                Picker("Training phases", selection: $viewModel.programStructurePreset) {
                    ForEach(DynamicProgramBuilderViewModel.ProgramStructurePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Text(viewModel.programStructurePreset.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .onChange(of: viewModel.totalWeeksTemplate) { _, _ in viewModel.applyTotalWeeksOrLengthChange() }
            .onChange(of: viewModel.customTotalProgramWeeks) { _, _ in
                guard viewModel.totalWeeksTemplate == .custom else { return }
                viewModel.applyTotalWeeksOrLengthChange()
            }
            .onChange(of: viewModel.programStructurePreset) { old, new in
                guard old != new else { return }
                viewModel.applyProgramStructurePresetChange(from: old)
            }

            if programStructureSummaryVisible {
                Section("What we’ll build") {
                    Text(programPhaseSummaryLine)
                        .font(.subheadline)
                }
            }

            if viewModel.programStructurePreset != .singlePhase {
                Toggle("Customize phases", isOn: $viewModel.showPhaseCustomization)
            }

            if phaseEditorVisible {
                Section("Your phases") {
                    ForEach($viewModel.request.blockSpecs) { $spec in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Phase name", text: $spec.title)
                            Picker("Phase goal", selection: $spec.focus.kind) {
                                ForEach(BlockFocusKind.allCases, id: \.self) { k in
                                    Text(k.userFriendlyShortLabel).tag(k)
                                }
                            }
                            Stepper(value: $spec.durationWeeks, in: 1 ... 52) {
                                Text("Duration: \(spec.durationWeeks) weeks")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Toggle("Advanced settings", isOn: $viewModel.showAdvancedSettings)
            }

            if viewModel.showAdvancedSettings {
                advancedSettingsSection
            }
        }
        .onChange(of: viewModel.showPhaseCustomization) { _, isOn in
            if !isOn, viewModel.programStructurePreset != .custom {
                viewModel.applyProgramStructureSelections()
            }
        }
    }

    private var advancedSettingsSection: some View {
        Group {
            Section("Training style") {
                Picker("Session length", selection: sessionDurationBinding) {
                    ForEach(DPSessionDurationPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }
                Picker("Intensity style", selection: intensityBinding) {
                    ForEach(DPIntensityPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }
                Picker("Progression style", selection: progressionBinding) {
                    ForEach(DPProgressionPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }
                Picker("Deload preference", selection: deloadBinding) {
                    ForEach(DPDeloadPick.allCases) { g in Text(g.rawValue).tag(g.rawValue) }
                }
                Picker("Cardio in program", selection: cardioPreferenceBinding) {
                    ForEach(CardioProgramPreference.allCases) { preference in
                        Text(preference.rawValue).tag(preference.rawValue)
                    }
                }
            }

            Section("Schedule variation") {
                Picker("Template variation", selection: $viewModel.request.splitInput.variationMode) {
                    ForEach(SplitBuilderVariationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                if SplitBuilderVariationMode(rawValue: viewModel.request.splitInput.variationMode) == .custom {
                    Stepper(value: Binding(
                        get: { viewModel.request.splitInput.desiredWorkoutRotationLength ?? viewModel.request.splitInput.sessionsPerWeek },
                        set: { viewModel.request.splitInput.desiredWorkoutRotationLength = $0 }
                    ), in: 1 ... 7) {
                        Text("Templates in rotation: \(viewModel.request.splitInput.desiredWorkoutRotationLength ?? viewModel.request.splitInput.sessionsPerWeek)")
                    }
                }
            }

            Section("Adaptation") {
                Picker("Busy day policy", selection: $viewModel.request.busyDayPolicy) {
                    ForEach(BusyDayPolicy.allCases, id: \.self) { pol in
                        Text(busyPolicyLabel(pol)).tag(pol)
                    }
                }
            }

            Section("Notes") {
                TextField("Limitations or injuries", text: $viewModel.request.splitInput.limitationsNotes, axis: .vertical)
                    .lineLimit(2 ... 5)
                TextField("Additional notes", text: $viewModel.request.splitInput.additionalNotes, axis: .vertical)
                    .lineLimit(2 ... 5)
                TextField("Priority muscles or lifts", text: $viewModel.request.splitInput.priorityMusclesOrLiftsNotes, axis: .vertical)
                    .lineLimit(2 ... 4)
            }
        }
    }

    // MARK: - Step 3 — Review & edit

    private var reviewAndEditStep: some View {
        Form {
            if viewModel.builderMode == .aiGenerate, viewModel.generatedProgram == nil {
                Section {
                    Button {
                        Task { await viewModel.generate(aiService: aiService, dataManager: dataManager) }
                    } label: {
                        if viewModel.isGenerating || viewModel.isConnectingToProxy {
                            HStack {
                                ProgressView()
                                Text(viewModel.generationStatusMessage ?? "Generating…")
                            }
                        } else {
                            Text(aiService.isConfigured ? "Generate with AI" : "Build from local presets")
                        }
                    }
                    .disabled(viewModel.isGenerating || viewModel.isConnectingToProxy)
                } footer: {
                    Text(aiService.isConfigured
                        ? "Uses your essentials and structure settings to draft a program."
                        : "No AI configured — uses FitLog’s built-in rotation templates.")
                }
            } else if viewModel.builderMode == .manualBuild, viewModel.generatedProgram == nil {
                Section {
                    Label("Manual program draft", systemImage: "square.and.pencil")
                    Text("A blank rotation is created automatically. Add slots below, then save to Plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = viewModel.errorMessage, !err.isEmpty {
                Section {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }
            }

            if viewModel.offersLocalPresetFallback, viewModel.generatedProgram == nil {
                Section {
                    Button {
                        Task { await viewModel.generateFromLocalPresets(dataManager: dataManager) }
                    } label: {
                        Label("Use built-in presets instead", systemImage: "books.vertical")
                    }
                    .disabled(viewModel.isGenerating || viewModel.isConnectingToProxy)
                } footer: {
                    Text("Creates a program locally without AI when the service is slow or unavailable.")
                }
            }

            if let program = viewModel.generatedProgram {
                Section("Checks") {
                    ProgramValidationBanner(result: viewModel.programValidationResult)
                }

                Section("Timeline") {
                    DynamicProgramTimelineView(program: program, anchorDate: viewModel.programAnchorDate, builderViewModel: viewModel)
                        .frame(minHeight: 180)
                }

                Section("Calendar overview") {
                    ProgramCalendarPreviewView(
                        program: program,
                        anchorDate: viewModel.programAnchorDate,
                        weeklySetTotalsByBlock: ProgramCalendarPreviewView.weeklySetTotalsPerBlock(program: program)
                    )
                    .frame(minHeight: 160)
                }

                if viewModel.builderMode == .manualBuild {
                    ManualBlockEditorView(viewModel: viewModel)
                }

                if !viewModel.generationBalanceWarnings.isEmpty {
                    Section("Balance checks") {
                        ForEach(viewModel.generationBalanceWarnings) { w in
                            Label(w.message, systemImage: w.severity == .caution ? "exclamationmark.triangle.fill" : "info.circle")
                                .font(.caption)
                                .foregroundStyle(w.severity == .caution ? Color.orange : Color.secondary)
                        }
                    }
                }

                DynamicProgramGeneratedTemplateEditor(viewModel: viewModel)

                Section("Start date") {
                    DatePicker("Program starts", selection: $viewModel.programAnchorDate, displayedComponents: [.date])
                }

                if let applyErr = viewModel.applyErrorMessage, !applyErr.isEmpty {
                    Section {
                        Text(applyErr).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var reviewPrimaryDisabled: Bool {
        if viewModel.generatedProgram == nil {
            return viewModel.isGenerating || viewModel.isConnectingToProxy
        }
        return viewModel.isApplying
            || viewModel.flattenedEditableDaysForConfirmation().isEmpty
            || !viewModel.programValidationResult.canSaveToPlan
    }

    private func handleReviewPrimaryAction() {
        if viewModel.generatedProgram == nil {
            if viewModel.builderMode == .manualBuild {
                viewModel.ensureManualDraftIfNeeded()
            } else {
                Task { await viewModel.generate(aiService: aiService, dataManager: dataManager) }
            }
        } else {
            showApplyReviewSheet = true
        }
    }

    private var programStructureSummaryVisible: Bool {
        !viewModel.showPhaseCustomization && viewModel.programStructurePreset != .custom
    }

    private var phaseEditorVisible: Bool {
        viewModel.programStructurePreset == .custom || viewModel.showPhaseCustomization
    }

    private var programPhaseSummaryLine: String {
        viewModel.request.blockSpecs.map { spec in
            "\(spec.title.isEmpty ? "Phase" : spec.title) (\(spec.durationWeeks) wk)"
        }.joined(separator: " → ")
    }

    private var goalBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.primaryGoal }, set: { viewModel.request.splitInput.primaryGoal = $0 })
    }

    private var equipmentBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.equipment }, set: { viewModel.request.splitInput.equipment = $0 })
    }

    private var experienceBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.experienceLevel }, set: { viewModel.request.splitInput.experienceLevel = $0 })
    }

    private var sessionDurationBinding: Binding<String> {
        Binding(
            get: { SessionDurationBuckets.pickerLabel(fromMinutes: viewModel.request.splitInput.sessionDurationMinutes) },
            set: { viewModel.request.splitInput.sessionDurationMinutes = SessionDurationBuckets.minutes(fromPickerLabel: $0) }
        )
    }

    private var intensityBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.intensityStyle }, set: { viewModel.request.splitInput.intensityStyle = $0 })
    }

    private var progressionBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.progressionStyle }, set: { viewModel.request.splitInput.progressionStyle = $0 })
    }

    private var deloadBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.deloadPreference }, set: { viewModel.request.splitInput.deloadPreference = $0 })
    }

    private var cardioPreferenceBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.cardioPreference }, set: { viewModel.request.splitInput.cardioPreference = $0 })
    }

    private var splitBinding: Binding<String> {
        Binding(get: { viewModel.request.splitInput.splitPreference }, set: { viewModel.request.splitInput.splitPreference = $0 })
    }

    private var weekdayPickGrid: some View {
        let symbols = calendar.shortWeekdaySymbols
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(1 ... 7, id: \.self) { weekday in
                let sym = symbols[(weekday + calendar.firstWeekday - 2) % 7]
                let on = viewModel.request.splitInput.preferredWeekdays.contains(weekday)
                Button { toggleWeekday(weekday) } label: {
                    VStack(spacing: 4) {
                        Text(String(sym.prefix(3))).font(.caption2.weight(.semibold))
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? Color.accentColor : Color.secondary.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(on ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(sym) training day")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        var s = viewModel.request.splitInput.preferredWeekdays
        if let idx = s.firstIndex(of: weekday) { s.remove(at: idx) } else { s.append(weekday); s.sort() }
        viewModel.request.splitInput.preferredWeekdays = s
        if viewModel.request.splitInput.sessionsPerWeek > maxSessionsAllowed {
            viewModel.request.splitInput.sessionsPerWeek = maxSessionsAllowed
        }
    }

    private func busyPolicyLabel(_ pol: BusyDayPolicy) -> String {
        switch pol {
        case .compress: return "Compress — prefer fewer heavier days"
        case .shift: return "Shift — extend the current block"
        case .flexDay: return "Flex day — lighter recovery template"
        case .skip: return "Skip — keep rotation as-is"
        }
    }
}

#Preview("Light") {
    let schema = Schema(versionedSchema: FitLogSchemaV4.self)
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try! ModelContainer(for: schema, migrationPlan: FitLogMigrationPlan.self, configurations: config)
    let data = DataManager(modelContainer: container)
    let vm = DynamicProgramBuilderViewModel()
    NavigationStack {
        DynamicProgramBuilderView(viewModel: vm)
    }
    .environmentObject(AIService(apiKey: nil, baseURL: nil))
    .environment(data)
}
