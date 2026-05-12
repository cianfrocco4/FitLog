//
//  ManualSplitBuilderView.swift
//  FitLog
//
//  Manual split builder that uses the same flexible workout proposal/apply path
//  as AI-generated splits.
//

import SwiftUI

private enum ManualSplitStep {
    case setup
    case editor
}

struct ManualSplitBuilderView: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.modelContext) private var modelContext

    @State private var preset: SplitBuilderManualPreset = .pushPullLegs
    @State private var sessionsPerWeek = 4
    @State private var variationMode: SplitBuilderVariationMode = .balanced
    @State private var customRotationLength = 6
    @State private var selectedWeekdays: Set<Int> = []
    @State private var updateTrainingProgram = true
    @State private var step: ManualSplitStep = .setup
    @State private var editableDays: [SplitBuilderEditableDay] = []
    @State private var expandedDayIds: Set<UUID> = []
    @State private var isApplying = false
    @State private var showApplySuccess = false
    @State private var applySuccessMessage = ""
    @State private var showApplyConfirmation = false
    @State private var saveAsPreset = false
    @State private var presetName = ""
    @State private var slotPickerForSlot: SplitBuilderEditableSlot?
    @State private var slotPickerDayBinding: Binding<SplitBuilderEditableDay>?
    @State private var editMode: EditMode = .active
    @State private var musclePickerSlot: SplitBuilderEditableSlot?
    @State private var musclePickerDayBinding: Binding<SplitBuilderEditableDay>?

    init(
        preloadedDays: [SplitBuilderEditableDay] = [],
        preloadedSessions: Int = 4,
        preloadedWeekdays: [Int] = []
    ) {
        if !preloadedDays.isEmpty {
            _editableDays = State(initialValue: preloadedDays)
            _sessionsPerWeek = State(initialValue: preloadedSessions)
            _selectedWeekdays = State(initialValue: Set(preloadedWeekdays))
            _step = State(initialValue: .editor)
            _expandedDayIds = State(initialValue: Set(preloadedDays.map { $0.id }))
        }
    }

    private var maxSessionsAllowed: Int {
        selectedWeekdays.isEmpty ? 7 : max(1, selectedWeekdays.count)
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

    private var stats: SplitProposalProgramStats {
        SplitProposalProgramAnalyzer.stats(for: analyzerDays)
    }

    private var desiredRotationLength: Int {
        variationMode.targetRotationLength(
            sessionsPerWeek: sessionsPerWeek,
            splitPreferenceText: preset.rawValue,
            customCount: boundedCustomRotationLength
        )
    }

    private var boundedCustomRotationLength: Int {
        min(max(1, customRotationLength), 7)
    }

    private var warnings: [SplitProposalProgramWarning] {
        SplitProposalProgramAnalyzer.warnings(
            stats: stats,
            days: analyzerDays,
            context: SplitProposalProgramAnalyzer.Context(
                primaryGoal: "Manual split",
                experienceLevel: "Intermediate",
                sessionDurationMinutes: nil,
                priorityNotes: "",
                variationMode: variationMode.rawValue,
                sessionsPerWeek: sessionsPerWeek,
                desiredRotationLength: desiredRotationLength,
                splitPreference: preset.rawValue
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .setup:
                    setupView
                case .editor:
                    editorView
                }
            }
            .navigationTitle(step == .setup ? "Manual split builder" : "Build your split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if step == .editor {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Setup") { step = .setup }
                    }
                }
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
            let saved = SplitBuilderPreferencesStore.load()
            if let raw = saved.variationModeRaw,
               let mode = SplitBuilderVariationMode(rawValue: raw) {
                variationMode = mode
            }
            if let n = saved.customRotationLength {
                customRotationLength = min(max(1, n), 7)
            }
        }
        .onChange(of: variationMode) { _, _ in persistVariationDefaults() }
        .onChange(of: customRotationLength) { _, _ in persistVariationDefaults() }
        .sheet(isPresented: $showApplyConfirmation) {
            SplitApplyConfirmationView(
                days: editableDays,
                sessionsPerWeek: min(sessionsPerWeek, maxSessionsAllowed),
                preferredWeekdays: Array(selectedWeekdays).sorted(),
                rationale: "Manual split built in FitLog.",
                updateTrainingProgram: updateTrainingProgram,
                dataVM: dataVM,
                onConfirm: { anchorDate in
                    Task { await applyWithAnchor(anchorDate) }
                    showApplyConfirmation = false
                },
                onCancel: { showApplyConfirmation = false }
            )
        }
        .sheet(item: Binding(
            get: { slotPickerForSlot.map { SlotPickerIdentity(slot: $0) } },
            set: { slotPickerForSlot = $0?.slot }
        )) { identity in
            SlotLibraryPickerSheet(slot: identity.slot) { exercise in
                if let dayBinding = slotPickerDayBinding {
                    var day = dayBinding.wrappedValue
                    if let idx = day.slots.firstIndex(where: { $0.id == identity.slot.id }) {
                        day.slots[idx].suggestedExerciseName = exercise.name
                        day.slots[idx].suggestedExerciseOverrideId = exercise.id
                        if day.slots[idx].targetMuscleNames == [MuscleGroup.other.rawValue] {
                            day.slots[idx].targetMuscleNames = exercise.targetedMuscles.map(\.rawValue)
                        }
                    }
                    dayBinding.wrappedValue = day
                }
                slotPickerForSlot = nil
                slotPickerDayBinding = nil
            }
            .environment(dataVM)
            .environmentObject(aiService)
        }
        .sheet(item: Binding(
            get: { musclePickerSlot.map { MusclePickerIdentity(slot: $0) } },
            set: { musclePickerSlot = $0?.slot }
        )) { identity in
            NavigationStack {
                SplitMuscleMultiPickerView(
                    initial: identity.slot.targetMuscleNames.compactMap { MuscleGroup(rawValue: $0) },
                    onDone: { muscles in
                        if let dayBinding = musclePickerDayBinding {
                            var day = dayBinding.wrappedValue
                            if let idx = day.slots.firstIndex(where: { $0.id == identity.slot.id }) {
                                day.slots[idx].targetMuscleNames = muscles.map(\.rawValue)
                            }
                            dayBinding.wrappedValue = day
                        }
                        musclePickerSlot = nil
                        musclePickerDayBinding = nil
                    },
                    onCancel: {
                        musclePickerSlot = nil
                        musclePickerDayBinding = nil
                    }
                )
            }
        }
    }

    private struct MusclePickerIdentity: Identifiable {
        let slot: SplitBuilderEditableSlot
        var id: UUID { slot.id }
    }

    private struct SlotPickerIdentity: Identifiable {
        let slot: SplitBuilderEditableSlot
        var id: UUID { slot.id }
    }

    private var setupView: some View {
        List {
            Section {
                Text("Pick a starting structure. You’ll edit every day and slot before saving, with the same balance checks as the AI builder.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Starting point") {
                ForEach(SplitBuilderManualPreset.allCases) { p in
                    Button {
                        preset = p
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: preset == p ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(preset == p ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(p.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(p.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Stepper("Sessions per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...maxSessionsAllowed)
                weekdayMultiSelect
                Toggle("Set as my training program", isOn: $updateTrainingProgram)
            } header: {
                Text("Schedule")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekdays are optional. If you leave them blank, FitLog will spread the cycle across the week.")
                    if !selectedWeekdays.isEmpty {
                        Text("Sessions per week is capped by selected days. Add more days first if you want more sessions.")
                    }
                }
                .font(.caption)
            }

            variationSection

            Section {
                Button {
                    startEditing()
                } label: {
                    Label("Build split", systemImage: "rectangle.stack.badge.plus")
                        .font(.headline)
                }
            }
        }
    }

    private var variationSection: some View {
        Section {
            Picker("Variation", selection: $variationMode) {
                ForEach(SplitBuilderVariationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            if variationMode == .custom {
                Stepper(
                    "Templates in rotation: \(boundedCustomRotationLength)",
                    value: $customRotationLength,
                    in: 1...7
                )
            }
            Text(variationMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(
                variationMode.rotationSummary(
                    sessionsPerWeek: sessionsPerWeek,
                    splitPreferenceText: preset.rawValue,
                    customCount: boundedCustomRotationLength
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text("Variety & rotation")
        } footer: {
            Text("Rotation length can be longer than weekly sessions, so A/B days cycle across multiple weeks.")
                .font(.caption)
        }
    }

    private var editorView: some View {
        List {
            statsSection
            warningsSection
            daysSection
            applySection
        }
        .environment(\.editMode, $editMode)
        .onAppear {
            if expandedDayIds.isEmpty {
                expandedDayIds = Set(editableDays.map(\.id))
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        Section {
            LabeledContent("Weekly sets", value: "\(stats.totalHardSetsPerWeek)")
            LabeledContent("Split style", value: stats.inferredSplitStyle)
            LabeledContent("Muscle tags", value: "\(stats.distinctMuscleGroupsTouched)")
            LabeledContent("Rotation templates", value: "\(editableDays.count)")
            LabeledContent("Sessions / week", value: "\(sessionsPerWeek)")
            LabeledContent(
                "Push / pull / legs",
                value: "\(stats.pushOrientedSets) / \(stats.pullOrientedSets) / \(stats.legOrientedSets)"
            )
        } header: {
            Text("Program snapshot")
        } footer: {
            if editableDays.count != sessionsPerWeek {
                Text("This rotation has more templates than weekly sessions, so exact workouts repeat across multiple weeks.")
            }
        }
    }

    @ViewBuilder
    private var warningsSection: some View {
        if !warnings.isEmpty {
            Section("Balance checks") {
                ForEach(warnings) { w in
                    Label(w.message, systemImage: w.severity == .caution ? "exclamationmark.triangle.fill" : "info.circle")
                        .font(.caption)
                        .foregroundStyle(w.severity == .caution ? Color.orange : Color.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var daysSection: some View {
        Section {
            ForEach(editableDays) { day in
                DisclosureGroup(isExpanded: Binding(
                    get: { expandedDayIds.contains(day.id) },
                    set: { on in
                        if on { expandedDayIds.insert(day.id) } else { expandedDayIds.remove(day.id) }
                    }
                )) {
                    dayEditor(day: bindingForDay(id: day.id))
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.name.isEmpty ? "Untitled day" : day.name)
                            .font(.headline)
                        Text("\(day.slots.count) slot\(day.slots.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contextMenu {
                    Button {
                        duplicateAsVariant(day: day)
                    } label: {
                        Label("Duplicate as variant", systemImage: "doc.on.doc")
                    }
                }
            }
            .onMove { from, to in
                editableDays.move(fromOffsets: from, toOffset: to)
            }
        } header: {
            Text("Training days")
        }
    }

    @ViewBuilder
    private var applySection: some View {
        Section {
            Toggle("Save as preset", isOn: $saveAsPreset)
            if saveAsPreset {
                TextField("Preset name", text: $presetName, prompt: Text("My custom split"))
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                showApplyConfirmation = true
            } label: {
                if isApplying {
                    HStack {
                        ProgressView()
                        Text("Applying…")
                    }
                } else {
                    Label("Apply split", systemImage: "checkmark.circle.fill")
                }
            }
            .disabled(isApplying || editableDays.flatMap(\.slots).isEmpty)

            HStack {
                Button {
                    var next = editableDays
                    next.append(
                        SplitBuilderEditableDay(
                            name: "Day \(editableDays.count + 1)",
                            focus: "",
                            slots: []
                        )
                    )
                    editableDays = next
                } label: {
                    Label("Add day", systemImage: "plus.circle")
                }
                .font(.caption)

                Spacer()

                Button(role: .destructive) {
                    editableDays.removeLast()
                } label: {
                    Label("Remove last", systemImage: "minus.circle")
                }
                .font(.caption)
                .disabled(editableDays.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func dayEditor(day: Binding<SplitBuilderEditableDay>) -> some View {
        TextField("Day name", text: day.name)
            .font(.headline)
        TextField("Focus", text: day.focus)
            .font(.caption)
            .foregroundStyle(.secondary)

        ForEach(day.wrappedValue.slots) { slotValue in
            manualSlotRow(slot: bindingForSlot(day: day, slotId: slotValue.id), day: day)
        }
        .onMove { from, to in
            var d = day.wrappedValue
            d.slots.move(fromOffsets: from, toOffset: to)
            day.wrappedValue = d
        }

        Button {
            var d = day.wrappedValue
            d.slots.append(
                SplitBuilderEditableSlot(
                    label: "New slot",
                    targetMuscleNames: [MuscleGroup.other.rawValue],
                    sets: 3,
                    reps: "8-12"
                )
            )
            day.wrappedValue = d
        } label: {
            Label("Add slot", systemImage: "plus.circle")
        }
        .font(.subheadline)

        if !day.wrappedValue.slots.isEmpty {
            Button(role: .destructive) {
                var d = day.wrappedValue
                d.slots.removeLast()
                day.wrappedValue = d
            } label: {
                Label("Remove last slot", systemImage: "minus.circle")
            }
            .font(.subheadline)
        }
    }

    private func bindingForSlot(
        day: Binding<SplitBuilderEditableDay>,
        slotId: UUID
    ) -> Binding<SplitBuilderEditableSlot> {
        Binding(
            get: {
                day.wrappedValue.slots.first(where: { $0.id == slotId })
                    ?? SplitBuilderEditableSlot(
                        label: "Slot",
                        targetMuscleNames: [MuscleGroup.other.rawValue],
                        sets: 3,
                        reps: "8-12"
                    )
            },
            set: { new in
                var d = day.wrappedValue
                guard let i = d.slots.firstIndex(where: { $0.id == slotId }) else { return }
                d.slots[i] = new
                day.wrappedValue = d
            }
        )
    }

    private func manualSlotRow(slot: Binding<SplitBuilderEditableSlot>, day: Binding<SplitBuilderEditableDay>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Slot label", text: slot.label)
                .font(.body)

            Button {
                slotPickerForSlot = slot.wrappedValue
                slotPickerDayBinding = day
            } label: {
                HStack {
                    Text(slot.wrappedValue.suggestedExerciseName ?? "Choose exercise from library")
                        .font(.caption)
                        .foregroundStyle(slot.wrappedValue.suggestedExerciseName == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            }

            HStack {
                Text(muscleSummary(slot.wrappedValue))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    musclePickerSlot = slot.wrappedValue
                    musclePickerDayBinding = day
                } label: {
                    Label("Edit muscles", systemImage: "pencil.circle")
                        .font(.caption2)
                }
            }

            Text(SplitBuilderSupportText.slotSuggestedExerciseLine(slot.wrappedValue, library: dataVM.globalExercises))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Stepper("Sets: \(slot.wrappedValue.sets)", value: slot.sets, in: 1...10)
                    .font(.caption)
                TextField("Reps", text: slot.reps)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 72)
            }
        }
        .padding(.vertical, 4)
    }

    private func bindingForDay(id: UUID) -> Binding<SplitBuilderEditableDay> {
        Binding(
            get: { editableDays.first(where: { $0.id == id }) ?? SplitBuilderEditableDay(name: "Day", focus: "", slots: []) },
            set: { new in
                guard let i = editableDays.firstIndex(where: { $0.id == id }) else { return }
                editableDays[i] = new
            }
        )
    }

    private func startEditing() {
        sessionsPerWeek = min(sessionsPerWeek, maxSessionsAllowed)
        editableDays = SplitBuilderSharedFactory.presetDays(
            preset: preset,
            count: sessionsPerWeek,
            variationMode: variationMode,
            customRotationLength: boundedCustomRotationLength,
            library: dataVM.globalExercises
        )
        expandedDayIds = Set(editableDays.map(\.id))
        step = .editor
    }

    @MainActor
    private func applyWithAnchor(_ anchorDate: Date) async {
        isApplying = true
        defer { isApplying = false }

        let effectiveSessions = min(sessionsPerWeek, maxSessionsAllowed)

        // Save preset if requested (Task 19)
        if saveAsPreset {
            let store = SplitPresetStore(modelContext: modelContext)
            let name = presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Unnamed Split \(Date().formatted(date: .abbreviated, time: .omitted))"
                : presetName
            _ = store.savePreset(
                name: name,
                notes: "",
                sessionsPerWeek: effectiveSessions,
                preferredWeekdays: Array(selectedWeekdays).sorted(),
                days: editableDays
            )
        }

        if updateTrainingProgram {
            let templates = editableDays.map { day in
                BlockWeeklyTemplate(
                    id: day.id,
                    dayName: day.name,
                    focus: day.focus,
                    slots: day.slots,
                    dayNotes: day.dayNotes
                )
            }
            let block = ProgramBlock(
                name: "Manual program",
                focus: BlockFocus(kind: .general, emphasisLabel: ""),
                durationWeeks: 8,
                weeklyTemplates: templates,
                progressionStrategy: .doubleProgression
            )
            let programName = "Manual — \(Date().formatted(date: .abbreviated, time: .omitted))"
            let program = DynamicProgram(
                name: programName,
                blocks: [block],
                defaultSessionsPerWeek: effectiveSessions,
                preferredWeekdays: Array(selectedWeekdays).sorted(),
                busyDayPolicy: .skip
            )
            let anchorStart = Calendar.current.startOfDay(for: anchorDate)
            if dataVM.applyDynamicProgram(program, anchorDate: anchorStart) {
                applySuccessMessage = "Created \(templates.count) workout template\(templates.count == 1 ? "" : "s"). Your Plan tab now follows this dynamic program."
                showApplySuccess = true
                return
            }
        }

        let p = SplitBuilderApplyService.apply(
            days: editableDays,
            dataVM: dataVM,
            sessionsPerWeek: effectiveSessions,
            preferredWeekdays: Array(selectedWeekdays).sorted(),
            updateTrainingProgram: updateTrainingProgram,
            rationale: "Manual split built in FitLog.",
            anchorDate: anchorDate
        )
        let planLine = updateTrainingProgram
            ? "Your Plan tab now follows this cycle."
            : "Your Plan calendar was not changed; new templates are in your workout list."
        applySuccessMessage = "Created \(p.workouts.count) workout template\(p.workouts.count == 1 ? "" : "s"). \(planLine)"
        showApplySuccess = true
    }

    private func duplicateAsVariant(day: SplitBuilderEditableDay) {
        // Auto-suffix with A/B variants
        let baseName = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let variantSuffix = baseName.hasSuffix(" A") ? " B" : " A"
        let newName = baseName + variantSuffix
        
        // Copy slots with new IDs
        let newSlots = day.slots.map { slot in
            SplitBuilderEditableSlot(
                id: UUID(),
                label: slot.label,
                targetMuscleNames: slot.targetMuscleNames,
                sets: slot.sets,
                reps: slot.reps,
                suggestedExerciseName: slot.suggestedExerciseName,
                suggestedExerciseOverrideId: slot.suggestedExerciseOverrideId
            )
        }
        
        let newDay = SplitBuilderEditableDay(
            id: UUID(),
            name: newName,
            focus: day.focus,
            slots: newSlots
        )
        
        editableDays.append(newDay)
        expandedDayIds.insert(newDay.id)
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
                    if on {
                        selectedWeekdays.remove(wd)
                    } else {
                        selectedWeekdays.insert(wd)
                    }
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? Color.accentColor.opacity(0.18) : Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func muscleSummary(_ slot: SplitBuilderEditableSlot) -> String {
        SplitBuilderSupportText.slotMuscleOutcomeLine(slot)
    }

    private func persistVariationDefaults() {
        var saved = SplitBuilderPreferencesStore.load()
        saved.variationModeRaw = variationMode.rawValue
        saved.customRotationLength = boundedCustomRotationLength
        SplitBuilderPreferencesStore.save(saved)
    }
}
