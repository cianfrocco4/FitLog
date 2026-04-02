//
//  AISplitBuilderView.swift
//  FitLog
//
//  Wizard + preview for AI-generated workout splits (Chat Completions JSON).
//

import SwiftUI

private enum SplitBuilderLimits {
    static let maxComposedContextChars = 600
    static let maxOptionalFieldChars = 220
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

// MARK: - Editable proposal models

private struct EditableExercise: Identifiable {
    let id = UUID()
    var name: String
    var sets: Int
    var reps: String
    /// When set, apply uses this library exercise regardless of the text field.
    var libraryExerciseOverrideId: UUID? = nil
}

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
    var isSlotDay: Bool
    var exercises: [EditableExercise]
    var slots: [EditableSlot]
}

extension EditableDay {
    init(from day: WorkoutSplitProposalDay) {
        self.name = day.name
        self.focus = day.focus ?? ""
        self.isSlotDay = day.isSlotTemplateDay
        self.exercises = day.exercises.map {
            EditableExercise(name: $0.name, sets: $0.sets, reps: $0.reps, libraryExerciseOverrideId: $0.libraryExerciseOverrideId)
        }
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
    }
}

// MARK: - View

struct AISplitBuilderView: View {
    @EnvironmentObject private var dataVM: DataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var primaryGoal: PrimaryTrainingGoal = .general
    @State private var equipment: EquipmentAccess = .fullGym
    @State private var splitPreference: SplitStylePreference = .noPreference
    @State private var definitionPreference: WorkoutSplitDefinitionPreference = .concreteLists
    @State private var experience: ExperiencePick = .intermediate
    @State private var limitationsNotes = ""
    @State private var additionalNotes = ""

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

    @State private var currentStep: WizardStep = .goals

    private enum LibraryPickContext: Identifiable {
        case concreteExercise(dayId: UUID, exerciseId: UUID)
        case slotSuggested(dayId: UUID, slotId: UUID)

        var id: String {
            switch self {
            case .concreteExercise(let d, let e): return "ex-\(d.uuidString)-\(e.uuidString)"
            case .slotSuggested(let d, let s): return "slot-\(d.uuidString)-\(s.uuidString)"
            }
        }
    }

    private var calendar: Calendar { .current }

    private enum WizardStep: Int, CaseIterable {
        case goals
        case schedule
        case details
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
        }
        .sheet(item: $libraryPickContext) { ctx in
            NavigationStack {
                SplitLibraryPickerView(exercises: dataVM.globalExercises) { ex in
                    applyLibraryPick(context: ctx, exercise: ex)
                    libraryPickContext = nil
                }
            }
        }
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
                    Task { await generate() }
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
                Picker("Day definition", selection: $definitionPreference) {
                    ForEach(WorkoutSplitDefinitionPreference.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                Picker("Experience level", selection: $experience) {
                    ForEach(ExperiencePick.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            } header: {
                Text("Your training")
            } footer: {
                Text("Day definition controls whether the AI outputs fixed exercise lists, open slots (muscle + optional exercise hint), or a mix.")
            }
        }
    }

    // MARK: - Step 2: Schedule

    private var schedulePage: some View {
        Form {
            Section {
                Stepper("Sessions per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...7)
                weekdayMultiSelect
            } header: {
                Text("Availability")
            } footer: {
                Text("Pick your preferred training days, or leave none selected for the default Mon\u{2013}Fri pool.")
            }

            if !selectedWeekdays.isEmpty && sessionsPerWeek > selectedWeekdays.count {
                Section {
                    Label(
                        "You selected \(sessionsPerWeek) sessions but only \(selectedWeekdays.count) training day\(selectedWeekdays.count == 1 ? "" : "s")",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Step 3: Details + Generate

    private var detailsPage: some View {
        Form {
            Section {
                TextField("Injuries or movements to avoid", text: $limitationsNotes, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Anything else we should know?", text: $additionalNotes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Optional details")
            } footer: {
                Text("Examples: bad shoulder, no overhead pressing, prefer short workouts. Up to \(SplitBuilderLimits.maxOptionalFieldChars) characters each.")
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
        .keyboardDismissToolbar()
    }

    private var libraryApplyStats: (newCustom: Int, libraryLinks: Int) {
        var newCustom = 0
        var libraryLinks = 0
        for day in editableDays {
            if day.isSlotDay {
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
            } else {
                for ex in day.exercises {
                    if let oid = ex.libraryExerciseOverrideId,
                       dataVM.globalExercises.contains(where: { $0.id == oid }) {
                        libraryLinks += 1
                        continue
                    }
                    let trimmed = ex.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }
                    guard let r = ExerciseNameResolution.resolve(planName: trimmed, library: dataVM.globalExercises) else { continue }
                    switch r {
                    case .linked: libraryLinks += 1
                    case .createCustom: newCustom += 1
                    }
                }
            }
        }
        return (newCustom, libraryLinks)
    }

    private func applyLibraryPick(context: LibraryPickContext, exercise: Exercise) {
        switch context {
        case .concreteExercise(let dayId, let exerciseId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let eIdx = editableDays[dIdx].exercises.firstIndex(where: { $0.id == exerciseId }) else { return }
            editableDays[dIdx].exercises[eIdx].libraryExerciseOverrideId = exercise.id
        case .slotSuggested(let dayId, let slotId):
            guard let dIdx = editableDays.firstIndex(where: { $0.id == dayId }),
                  let sIdx = editableDays[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
            editableDays[dIdx].slots[sIdx].suggestedExerciseOverrideId = exercise.id
            editableDays[dIdx].slots[sIdx].suggestedExerciseName = exercise.name
        }
    }

    private func concreteExerciseOutcomeLine(_ exercise: EditableExercise) -> String {
        if let oid = exercise.libraryExerciseOverrideId,
           let ex = dataVM.globalExercises.first(where: { $0.id == oid }) {
            return "Uses \(ex.name) in your library (your pick)."
        }
        let trimmed = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Empty rows are skipped when you apply." }
        guard let r = ExerciseNameResolution.resolve(planName: trimmed, library: dataVM.globalExercises) else {
            return ""
        }
        switch r {
        case .linked(let ex):
            let n1 = ExerciseNameResolution.normalizationKey(trimmed)
            let n2 = ExerciseNameResolution.normalizationKey(ex.name)
            if n1 != n2 {
                return "Uses \(ex.name) in your library (matched from your plan text)."
            }
            return "Uses \(ex.name) in your library."
        case .createCustom(let name):
            return "Adds “\(name)” as a new custom exercise when you apply."
        }
    }

    private func slotMuscleOutcomeLine(_ slot: EditableSlot) -> String {
        let parsed = ExerciseNameResolution.resolveMuscleGroups(from: slot.targetMuscleNames)
        if !parsed.isEmpty {
            return "Targets: \(parsed.map(\.rawValue).joined(separator: ", "))."
        }
        let tokens = slot.targetMuscleNames.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if tokens.isEmpty {
            return "Add target muscles so this slot filters well; otherwise Other is used."
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
            return "No suggested default; you’ll pick an exercise when you start this workout."
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

    private func previewContent(_ p: WorkoutSplitProposal) -> some View {
        List {
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

            libraryChangesSection

            ForEach($editableDays) { $day in
                Section {
                    TextField("Day name", text: $day.name)
                        .font(.headline)
                    if !day.focus.isEmpty {
                        TextField("Focus", text: $day.focus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if day.isSlotDay {
                        Label("Flexible template", systemImage: "square.grid.3x3.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach($day.slots) { $slot in
                            editableSlotRow(slot: $slot) {
                                libraryPickContext = .slotSuggested(dayId: day.id, slotId: slot.id)
                            }
                        }
                        .onDelete { offsets in day.slots.remove(atOffsets: offsets) }
                        .onMove { from, to in day.slots.move(fromOffsets: from, toOffset: to) }

                        Button {
                            day.slots.append(EditableSlot(label: "New slot", targetMuscleNames: ["Other"], sets: 3, reps: "8-12", suggestedExerciseName: nil))
                        } label: {
                            Label("Add slot", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    } else {
                        Label("Saved workout", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach($day.exercises) { $ex in
                            editableExerciseRow(exercise: $ex) {
                                libraryPickContext = .concreteExercise(dayId: day.id, exerciseId: ex.id)
                            }
                        }
                        .onDelete { offsets in day.exercises.remove(atOffsets: offsets) }
                        .onMove { from, to in day.exercises.move(fromOffsets: from, toOffset: to) }

                        Button {
                            day.exercises.append(EditableExercise(name: "", sets: 3, reps: "8-12"))
                        } label: {
                            Label("Add exercise", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text(day.name)
                }
            }
            .onMove { from, to in editableDays.move(fromOffsets: from, toOffset: to) }

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
                    proposal = nil
                    originalProposal = nil
                    editableDays = []
                    errorBanner = nil
                }

                if let orig = originalProposal {
                    Button("Undo all edits", role: .destructive) {
                        editableDays = orig.workouts.map { EditableDay(from: $0) }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Preview row helpers

    private func editableExerciseRow(
        exercise: Binding<EditableExercise>,
        onPickInLibrary: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Exercise name", text: exercise.name)
                .font(.body)
            Text(concreteExerciseOutcomeLine(exercise.wrappedValue))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Stepper("Sets: \(exercise.wrappedValue.sets)", value: exercise.sets, in: 1...10)
                    .font(.caption)
                TextField("Reps", text: exercise.reps)
                    .font(.caption)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(spacing: 12) {
                Button("Choose in library", action: onPickInLibrary)
                    .font(.caption)
                if exercise.wrappedValue.libraryExerciseOverrideId != nil {
                    Button("Clear pick") {
                        exercise.libraryExerciseOverrideId.wrappedValue = nil
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func editableSlotRow(
        slot: Binding<EditableSlot>,
        onPickInLibrary: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Slot label", text: slot.label)
                .font(.body)
            TextField("Target muscles (comma-separated)", text: Binding(
                get: { slot.wrappedValue.targetMuscleNames.joined(separator: ", ") },
                set: { slot.wrappedValue.targetMuscleNames = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(slotMuscleOutcomeLine(slot.wrappedValue))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Stepper("Sets: \(slot.wrappedValue.sets)", value: slot.sets, in: 1...10)
                    .font(.caption)
                TextField("Reps", text: slot.reps)
                    .font(.caption)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("Suggested exercise (optional)", text: Binding(
                get: { slot.wrappedValue.suggestedExerciseName ?? "" },
                set: { slot.wrappedValue.suggestedExerciseName = $0.isEmpty ? nil : $0 }
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(slotSuggestedExerciseLine(slot.wrappedValue))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Choose default in library", action: onPickInLibrary)
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

    private func composedContextForAPI() -> String {
        var lines: [String] = []
        lines.append("Primary goal: \(primaryGoal.rawValue)")
        lines.append("Equipment: \(equipment.rawValue)")
        lines.append("Preferred split style: \(splitPreference.rawValue)")

        let lim = String(limitationsNotes.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !lim.isEmpty {
            lines.append("Injuries / movements to limit: \(lim)")
        }
        let extra = String(additionalNotes.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            lines.append("Additional notes: \(extra)")
        }

        return String(lines.joined(separator: "\n").prefix(SplitBuilderLimits.maxComposedContextChars))
    }

    @MainActor
    private func generate() async {
        errorBanner = nil
        isGenerating = true
        defer { isGenerating = false }

        aiService.wakeProxyHostIfNeeded()

        let allowed = dataVM.globalExercises.map(\.name).sorted()
        let existingTemplates = dataVM.userWorkouts.map(\.name) + dataVM.userWorkoutTemplates.map(\.name)
        let prefs = Array(selectedWeekdays).sorted()

        do {
            let result = try await aiService.generateWorkoutSplitProposal(
                interests: composedContextForAPI(),
                sessionsPerWeek: sessionsPerWeek,
                preferredWeekdays: prefs,
                experienceLevel: experience.rawValue,
                allowedExerciseNames: allowed,
                existingWorkoutTemplateNames: existingTemplates,
                definitionPreference: definitionPreference
            )
            proposal = result
            originalProposal = result
            editableDays = result.workouts.map { EditableDay(from: $0) }
        } catch {
            errorBanner = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func buildProposalFromEdits() -> WorkoutSplitProposal {
        let days = editableDays.map { day -> WorkoutSplitProposalDay in
            let exercises = day.exercises.map {
                WorkoutSplitProposalExerciseItem(
                    name: $0.name,
                    sets: $0.sets,
                    reps: $0.reps,
                    libraryExerciseOverrideId: $0.libraryExerciseOverrideId
                )
            }
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
                exercises: day.isSlotDay ? [] : exercises,
                slots: day.isSlotDay ? slots : []
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

        dismiss()
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
