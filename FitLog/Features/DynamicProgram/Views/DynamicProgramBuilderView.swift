//
//  DynamicProgramBuilderView.swift
//  FitLog
//
//  Unified wizard for dynamic / periodized programs (AI or local presets).
//

import SwiftData
import SwiftUI

// MARK: - Wizard pickers (raw strings match `AIProgramSplitEditorView`)

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
    static func fromStored(_ raw: String?) -> DPSessionDurationPick {
        guard let raw, let m = Self.allCases.first(where: { $0.rawValue == raw }) else { return .unspecified }
        return m
    }
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
            return "Creates a blank rotation from your schedule so you can add exercises without calling AI. Switch modes anytime — your edits are kept."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            wizardStepIndicator
                .padding(.horizontal)
                .padding(.top, 8)

            TabView(selection: $viewModel.wizardStep) {
                goalsStep.tag(DynamicProgramBuilderViewModel.WizardStep.goals)
                programTypeStep.tag(DynamicProgramBuilderViewModel.WizardStep.programType)
                scheduleStep.tag(DynamicProgramBuilderViewModel.WizardStep.schedule)
                busyDaysStep.tag(DynamicProgramBuilderViewModel.WizardStep.busyDays)
                generatePreviewStep.tag(DynamicProgramBuilderViewModel.WizardStep.generatePreview)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.22), value: viewModel.wizardStep)

            wizardChromeBar
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .navigationTitle("Program builder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSavedPresetBrowser = true
                } label: {
                    Label("Saved preset", systemImage: "square.stack.3d.up")
                }
                .accessibilityLabel("Load saved preset")
                .accessibilityHint("Opens saved split presets to copy schedule and notes into this program request.")
            }
            if dataManager.dynamicProgramState != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        confirmClearDynamicProgram = true
                    }
                    .accessibilityLabel("Clear dynamic program")
                    .accessibilityHint("Removes the active dynamic program from your plan. Library workouts are kept.")
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
            .accessibilityHint("Clears the dynamic program. Your Plan tab uses the saved rotation again.")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workout templates stay in your library. The Plan tab will follow your training program rotation again.")
        }
        .sensoryFeedback(.success, trigger: viewModel.generationSuccessCount)
        .sensoryFeedback(.success, trigger: viewModel.applySuccessCount)
        .alert("Saved to plan", isPresented: $viewModel.showApplySavedAlert) {
            Button("View Plan") {
                rootTabSelection?.wrappedValue = .plan
            }
            .accessibilityHint("Switches to the Plan tab.")

            Button("Done", role: .cancel) {
                dismiss()
            }
            .accessibilityHint("Closes this screen.")
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
            viewModel.loadPreferencesIfNeeded()
        }
        .onDisappear {
            viewModel.persistPreferencesToStore()
        }
        .onChange(of: viewModel.builderMode) { _, _ in
            viewModel.builderModeChangeCount += 1
            viewModel.persistPreferencesToStore()
            if viewModel.wizardStep == .generatePreview {
                viewModel.ensureManualDraftIfNeeded()
            }
        }
        .onChange(of: viewModel.wizardStep) { _, newStep in
            if newStep == .generatePreview {
                viewModel.ensureManualDraftIfNeeded()
            }
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

    private var wizardChromeBar: some View {
        HStack {
            Button("Back") {
                if let prev = DynamicProgramBuilderViewModel.WizardStep(rawValue: viewModel.wizardStep.rawValue - 1) {
                    viewModel.wizardStep = prev
                }
            }
            .disabled(viewModel.wizardStep == .goals)
            .accessibilityHint("Go to previous step")

            Spacer()

            if viewModel.wizardStep != .generatePreview {
                Button("Next") {
                    if let next = DynamicProgramBuilderViewModel.WizardStep(rawValue: viewModel.wizardStep.rawValue + 1) {
                        viewModel.wizardStep = next
                    }
                }
                .fontWeight(.semibold)
                .accessibilityHint("Go to next step")
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
    }

    // MARK: - Step 1 — Goals

    private var goalsStep: some View {
        Form {
            Section {
                Picker("Program build style", selection: $viewModel.builderMode) {
                    ForEach(DynamicProgramBuilderViewModel.ProgramBuilderMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Program build style")
                .accessibilityHint("Choose AI-assisted generation or a manual blank program. Your answers on every step are preserved when you switch.")

                Text(builderModeHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Builder")
            }

            Section {
                TextField("Program name", text: $viewModel.request.programName)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Program name")
                    .accessibilityHint("Name for this training program.")

                Picker("Primary goal", selection: goalBinding) {
                    ForEach(DPGoalPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("What you want this program to emphasize.")

                Picker("Equipment", selection: equipmentBinding) {
                    ForEach(DPEquipmentPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("Equipment you have access to.")

                Picker("Experience", selection: experienceBinding) {
                    ForEach(DPExperiencePick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("Training experience level.")

                Picker("Session length", selection: sessionDurationBinding) {
                    ForEach(DPSessionDurationPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("Typical session duration cap.")

                Picker("Intensity style", selection: intensityBinding) {
                    ForEach(DPIntensityPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("How heavy or voluminous sessions should feel.")

                Picker("Progression style", selection: progressionBinding) {
                    ForEach(DPProgressionPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("How loads and reps should progress over time.")

                Picker("Deload preference", selection: deloadBinding) {
                    ForEach(DPDeloadPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("How often you want planned easier weeks.")

                Picker("Cardio in program", selection: cardioPreferenceBinding) {
                    ForEach(CardioProgramPreference.allCases) { preference in
                        Text(preference.rawValue).tag(preference.rawValue)
                    }
                }
                .accessibilityLabel("Cardio in program")
                .accessibilityHint("Whether to add cardio finishers, dedicated cardio days, or a mix alongside strength work.")
            }

            Section("Notes") {
                TextField("Limitations or injuries", text: $viewModel.request.splitInput.limitationsNotes, axis: .vertical)
                    .lineLimit(2 ... 5)
                    .accessibilityLabel("Limitations or injuries")

                TextField("Additional notes for the generator", text: $viewModel.request.splitInput.additionalNotes, axis: .vertical)
                    .lineLimit(2 ... 5)
                    .accessibilityLabel("Additional notes for the generator")

                TextField("Priority muscles or lifts", text: $viewModel.request.splitInput.priorityMusclesOrLiftsNotes, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .accessibilityLabel("Priority muscles or lifts")

                TextField("Recovery context", text: $viewModel.request.splitInput.recoveryContextNotes, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .accessibilityLabel("Recovery context")
            }
        }
    }

    private var goalBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.primaryGoal },
            set: { viewModel.request.splitInput.primaryGoal = $0 }
        )
    }

    private var equipmentBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.equipment },
            set: { viewModel.request.splitInput.equipment = $0 }
        )
    }

    private var experienceBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.experienceLevel },
            set: { viewModel.request.splitInput.experienceLevel = $0 }
        )
    }

    private var sessionDurationBinding: Binding<String> {
        Binding(
            get: { SessionDurationBuckets.pickerLabel(fromMinutes: viewModel.request.splitInput.sessionDurationMinutes) },
            set: { raw in
                viewModel.request.splitInput.sessionDurationMinutes = SessionDurationBuckets.minutes(fromPickerLabel: raw)
            }
        )
    }

    private var intensityBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.intensityStyle },
            set: { viewModel.request.splitInput.intensityStyle = $0 }
        )
    }

    private var progressionBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.progressionStyle },
            set: { viewModel.request.splitInput.progressionStyle = $0 }
        )
    }

    private var deloadBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.deloadPreference },
            set: { viewModel.request.splitInput.deloadPreference = $0 }
        )
    }

    private var cardioPreferenceBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.cardioPreference },
            set: { viewModel.request.splitInput.cardioPreference = $0 }
        )
    }

    // MARK: - Step 2 — Program structure & split

    private var programTypeStep: some View {
        Form {
            Section {
                Picker("How long is your program?", selection: $viewModel.totalWeeksTemplate) {
                    ForEach(DynamicProgramBuilderViewModel.TotalWeeksTemplate.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .accessibilityHint("Total calendar length for this program.")

                if viewModel.totalWeeksTemplate == .custom {
                    Stepper(value: $viewModel.customTotalProgramWeeks, in: 1 ... 52) {
                        Text("Total: \(viewModel.customTotalProgramWeeks) weeks")
                    }
                    .accessibilityLabel("Custom program length in weeks")
                }

                Text("Phases below adjust to fit this length. You can change it any time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Length")
            }
            .onChange(of: viewModel.totalWeeksTemplate) { _, _ in
                viewModel.applyTotalWeeksOrLengthChange()
            }
            .onChange(of: viewModel.customTotalProgramWeeks) { _, _ in
                guard viewModel.totalWeeksTemplate == .custom else { return }
                viewModel.applyTotalWeeksOrLengthChange()
            }

            Section {
                Picker("Training phases", selection: $viewModel.programStructurePreset) {
                    ForEach(DynamicProgramBuilderViewModel.ProgramStructurePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .accessibilityHint("How you want training to change over the weeks.")

                Text(viewModel.programStructurePreset.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Structure")
            }
            .onChange(of: viewModel.programStructurePreset) { old, new in
                guard old != new else { return }
                viewModel.applyProgramStructurePresetChange(from: old)
            }

            if programStructureSummaryVisible {
                Section("What we’ll build") {
                    Text(programPhaseSummaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .accessibilityLabel(programPhaseSummaryLine)
                }
            }

            if viewModel.programStructurePreset != .singlePhase {
                Toggle("Customize phases", isOn: $viewModel.showPhaseCustomization)
                    .accessibilityHint("When on, you can edit each phase name, goal, length, and advanced progression.")
            }

            if phaseEditorVisible {
                Section("Your phases") {
                    ForEach($viewModel.request.blockSpecs) { $spec in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Phase name", text: $spec.title)
                                .accessibilityLabel("Phase name")
                            Picker("Phase goal", selection: $spec.focus.kind) {
                                ForEach(BlockFocusKind.allCases, id: \.self) { k in
                                    Text(k.userFriendlyShortLabel).tag(k)
                                }
                            }
                            .accessibilityLabel("Phase goal")
                            TextField("Extra detail (optional)", text: $spec.focus.emphasisLabel)
                                .accessibilityLabel("Extra detail for this phase")
                            Stepper(value: $spec.durationWeeks, in: 1 ... 52) {
                                Text("Duration: \(spec.durationWeeks) weeks")
                            }
                            .accessibilityLabel("Phase duration in weeks")
                            DisclosureGroup("Advanced") {
                                Picker("Progression", selection: $spec.progressionStrategy) {
                                    ForEach(ProgressionStrategy.allCases, id: \.self) { p in
                                        Text(dynamicProgramProgressionTitle(p)).tag(p)
                                    }
                                }
                                .accessibilityLabel("Progression strategy for this phase")
                            }
                            .accessibilityHint("Optional: how loads and reps progress in this phase.")

                            if spec.focus.kind == .hybrid || spec.focus.kind == .endurance {
                                let sessionsPerWeek = viewModel.request.splitInput.sessionsPerWeek
                                let cardioDays: Int = {
                                    if spec.focus.kind == .endurance {
                                        return min(max(1, sessionsPerWeek), 7)
                                    }
                                    return max(1, sessionsPerWeek / 2)
                                }()
                                Text("Plan for about \(cardioDays) cardio-focused session\(cardioDays == 1 ? "" : "s") per week in this phase. Add cardio slots in the template editor below.")
                                    .font(.caption)
                                    .foregroundStyle(FitlogPalette.chartSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityLabel("About \(cardioDays) cardio-focused sessions per week recommended for this phase.")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Picker("Split style", selection: splitBinding) {
                    ForEach(DPSplitPick.allCases) { g in
                        Text(g.rawValue).tag(g.rawValue)
                    }
                }
                .accessibilityHint("How you like to organize muscle groups across the week (PPL, upper lower, etc.).")
            } header: {
                Text("Weekly split style")
            }
        }
        .onChange(of: viewModel.showPhaseCustomization) { _, isOn in
            if !isOn, viewModel.programStructurePreset != .custom {
                viewModel.applyProgramStructureSelections()
            }
        }
    }

    private var programStructureSummaryVisible: Bool {
        !viewModel.showPhaseCustomization && viewModel.programStructurePreset != .custom
    }

    private var phaseEditorVisible: Bool {
        viewModel.programStructurePreset == .custom || viewModel.showPhaseCustomization
    }

    private var programPhaseSummaryLine: String {
        let parts = viewModel.request.blockSpecs.map { spec in
            "\(spec.title.isEmpty ? "Phase" : spec.title) (\(spec.durationWeeks) wk)"
        }
        return parts.joined(separator: " → ")
    }

    private var splitBinding: Binding<String> {
        Binding(
            get: { viewModel.request.splitInput.splitPreference },
            set: { viewModel.request.splitInput.splitPreference = $0 }
        )
    }

    // MARK: - Step 3 — Schedule

    private var scheduleStep: some View {
        Form {
            Section("Weekly rhythm") {
                Stepper(value: Binding(
                    get: { viewModel.request.splitInput.sessionsPerWeek },
                    set: { viewModel.request.splitInput.sessionsPerWeek = min(max(1, $0), maxSessionsAllowed) }
                ), in: 1 ... maxSessionsAllowed) {
                    Text("Sessions per week: \(viewModel.request.splitInput.sessionsPerWeek)")
                }
                .accessibilityLabel("Sessions per week")
                .accessibilityValue("\(viewModel.request.splitInput.sessionsPerWeek)")

                Picker("Template variation", selection: $viewModel.request.splitInput.variationMode) {
                    ForEach(SplitBuilderVariationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .accessibilityHint("How many distinct templates rotate across your training week.")

                if SplitBuilderVariationMode(rawValue: viewModel.request.splitInput.variationMode) == .custom {
                    Stepper(value: Binding(
                        get: { viewModel.request.splitInput.desiredWorkoutRotationLength ?? viewModel.request.splitInput.sessionsPerWeek },
                        set: { viewModel.request.splitInput.desiredWorkoutRotationLength = $0 }
                    ), in: 1 ... 7) {
                        Text("Templates in rotation: \(viewModel.request.splitInput.desiredWorkoutRotationLength ?? viewModel.request.splitInput.sessionsPerWeek)")
                    }
                    .accessibilityLabel("Custom rotation template count")
                }

                TextField("Variation notes", text: $viewModel.request.splitInput.variationNotes, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .accessibilityLabel("Variation notes")
            }

            Section("Preferred training days") {
                Text("Leave none selected to use weekdays Mon–Fri as the scheduling pool (same as Plan).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                weekdayPickGrid
            }
        }
    }

    private var weekdayPickGrid: some View {
        let symbols = calendar.shortWeekdaySymbols
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(1 ... 7, id: \.self) { weekday in
                let sym = symbols[(weekday + calendar.firstWeekday - 2) % 7]
                let on = viewModel.request.splitInput.preferredWeekdays.contains(weekday)
                Button {
                    toggleWeekday(weekday)
                } label: {
                    VStack(spacing: 4) {
                        Text(String(sym.prefix(3)))
                            .font(.caption2.weight(.semibold))
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .imageScale(.medium)
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
                .accessibilityValue(on ? "Selected" : "Not selected")
                .accessibilityHint("Double tap to toggle this weekday.")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func toggleWeekday(_ weekday: Int) {
        var s = viewModel.request.splitInput.preferredWeekdays
        if let idx = s.firstIndex(of: weekday) {
            s.remove(at: idx)
        } else {
            s.append(weekday)
            s.sort()
        }
        viewModel.request.splitInput.preferredWeekdays = s
        if viewModel.request.splitInput.sessionsPerWeek > maxSessionsAllowed {
            viewModel.request.splitInput.sessionsPerWeek = maxSessionsAllowed
        }
    }

    // MARK: - Step 4 — Busy days & adaptation

    private var busyDaysStep: some View {
        Form {
            Section {
                Picker("Busy day policy", selection: $viewModel.request.busyDayPolicy) {
                    ForEach(BusyDayPolicy.allCases, id: \.self) { pol in
                        Text(busyPolicyLabel(pol)).tag(pol)
                    }
                }
                .accessibilityHint("How FitLog should react when you mark a day busy or miss a planned session.")
            } header: {
                Text("Adaptation")
            } footer: {
                Text(busyPolicyFooter(viewModel.request.busyDayPolicy))
                    .font(.caption)
            }

            Section {
                TextField("Limitations (also used on Plan busy days)", text: $viewModel.request.splitInput.limitationsNotes, axis: .vertical)
                    .lineLimit(2 ... 5)
                    .accessibilityLabel("Limitations and constraints")
            } header: {
                Text("Recovery & constraints")
            } footer: {
                Text("You can mark specific calendar days busy from Plan. This policy controls how templates flex around those days.")
                    .font(.caption)
            }
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

    private func busyPolicyFooter(_ pol: BusyDayPolicy) -> String {
        switch pol {
        case .compress:
            return "Busy training days are treated as rest so you can catch up on remaining sessions that week."
        case .shift:
            return "Missed work can extend the active block so later phases start later."
        case .flexDay:
            return "Busy training days swap in a lighter recovery version of the planned template when possible."
        case .skip:
            return "No automatic template substitution; closest to classic rotation behavior."
        }
    }

    private func dynamicProgramProgressionTitle(_ p: ProgressionStrategy) -> String {
        switch p {
        case .linear: return "Linear"
        case .doubleProgression: return "Double progression"
        case .undulating: return "Undulating"
        case .autoregulated: return "Autoregulated"
        }
    }

    // MARK: - Step 5 — Generate & preview

    private var generatePreviewStep: some View {
        Form {
            if viewModel.builderMode == .aiGenerate {
                Section {
                    Button {
                        Task { await viewModel.generate(aiService: aiService, dataManager: dataManager) }
                    } label: {
                        if viewModel.isGenerating {
                            HStack {
                                ProgressView()
                                    .accessibilityLabel("Generating program")
                                Text("Generating…")
                            }
                        } else {
                            Text(aiService.isConfigured ? "Generate with AI" : "Build from local presets")
                        }
                    }
                    .disabled(viewModel.isGenerating)
                    .accessibilityLabel(viewModel.isGenerating ? "Generating program" : (aiService.isConfigured ? "Generate with AI" : "Build from local presets"))
                    .accessibilityHint(aiService.isConfigured ? "Calls the AI to propose a split, then builds a dynamic program from it." : "Builds a program from FitLog’s built-in rotation templates using your schedule and split style.")
                    .accessibilityAddTraits(.isButton)
                } footer: {
                    if aiService.isConfigured {
                        Text("If the AI is unavailable, configure a proxy or API key in Settings.")
                    } else {
                        Text("No AI client is configured — generation uses your library and local templates. Add an API key anytime to unlock AI drafts.")
                    }
                }
            } else {
                Section {
                    Label("Manual program draft", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityLabel("Manual program draft")

                    Text("A blank rotation is created when you open this step. Add slots and assign exercises below, then run checks before saving to Plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Manual mode uses a blank rotation you fill in yourself without calling AI.")
                }
            }

            if let err = viewModel.errorMessage, !err.isEmpty {
                Section {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .accessibilityLabel("Error")
                        .accessibilityValue(err)
                }
            }

            if let program = viewModel.generatedProgram {
                Section("Checks") {
                    ProgramValidationBanner(result: viewModel.programValidationResult)
                }

                Section("Timeline") {
                    DynamicProgramTimelineView(program: program, anchorDate: viewModel.programAnchorDate, builderViewModel: viewModel)
                        .frame(minHeight: 220)
                }
                .accessibilityElement(children: .contain)

                Section("Calendar overview") {
                    ProgramCalendarPreviewView(
                        program: program,
                        anchorDate: viewModel.programAnchorDate,
                        weeklySetTotalsByBlock: ProgramCalendarPreviewView.weeklySetTotalsPerBlock(program: program)
                    )
                    .frame(minHeight: 200)
                }
                .accessibilityElement(children: .contain)

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

                Section("Summary") {
                    LabeledContent("Name", value: program.name)
                    LabeledContent("Blocks", value: "\(program.blocks.count)")
                    LabeledContent("Sessions / week", value: "\(program.defaultSessionsPerWeek)")
                    if viewModel.builderMode == .manualBuild {
                        Label("Manual builder", systemImage: "hand.draw")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if viewModel.lastGenerationUsedLocalPresets {
                        Label("Local preset build", systemImage: "books.vertical")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Generated program summary")

                Section("Plan") {
                    DatePicker(
                        "Program starts",
                        selection: $viewModel.programAnchorDate,
                        displayedComponents: [.date]
                    )
                    .accessibilityLabel("Program start date")
                    .accessibilityHint("Used as the timeline anchor for blocks and the training calendar.")

                    Button {
                        showApplyReviewSheet = true
                    } label: {
                        Text("Review & save to plan")
                    }
                    .disabled(
                        viewModel.isApplying
                            || viewModel.flattenedEditableDaysForConfirmation().isEmpty
                            || !viewModel.programValidationResult.canSaveToPlan
                    )
                    .accessibilityLabel("Review and save to plan")
                    .accessibilityHint("Shows a confirmation screen, then creates workout templates and sets this dynamic program as your active plan.")
                    .accessibilityAddTraits(.isButton)
                }

                if let applyErr = viewModel.applyErrorMessage, !applyErr.isEmpty {
                    Section {
                        Text(applyErr)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel("Save error")
                            .accessibilityValue(applyErr)
                    }
                }
            }
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

#Preview("Dark", traits: .sizeThatFitsLayout) {
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
    .preferredColorScheme(.dark)
}
