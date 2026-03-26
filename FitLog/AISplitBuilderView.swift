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
}

private struct EditableSlot: Identifiable {
    let id = UUID()
    var label: String
    var targetMuscleNames: [String]
    var sets: Int
    var reps: String
    var suggestedExerciseName: String?
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
        self.exercises = day.exercises.map { EditableExercise(name: $0.name, sets: $0.sets, reps: $0.reps) }
        self.slots = day.slots.map {
            EditableSlot(label: $0.label, targetMuscleNames: $0.targetMuscleNames, sets: $0.sets, reps: $0.reps, suggestedExerciseName: $0.suggestedExerciseName)
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

    @State private var currentStep: WizardStep = .goals

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

            unresolvedNamesSection

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
                            editableSlotRow(slot: $slot)
                        }
                        .onDelete { offsets in day.slots.remove(atOffsets: offsets) }
                        .onMove { from, to in day.slots.move(fromOffsets: from, toOffset: to) }

                        Button {
                            day.slots.append(EditableSlot(label: "New slot", targetMuscleNames: ["other"], sets: 3, reps: "8-12", suggestedExerciseName: nil))
                        } label: {
                            Label("Add slot", systemImage: "plus.circle")
                                .font(.subheadline)
                        }
                    } else {
                        Label("Saved workout", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach($day.exercises) { $ex in
                            editableExerciseRow(exercise: $ex)
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

    private func editableExerciseRow(exercise: Binding<EditableExercise>) -> some View {
        let matched = dataVM.globalExercises.contains { $0.name.caseInsensitiveCompare(exercise.wrappedValue.name) == .orderedSame }
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Exercise name", text: exercise.name)
                    .font(.body)
                HStack(spacing: 12) {
                    Stepper("Sets: \(exercise.wrappedValue.sets)", value: exercise.sets, in: 1...10)
                        .font(.caption)
                    TextField("Reps", text: exercise.reps)
                        .font(.caption)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Spacer()
            Image(systemName: matched ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(matched ? .green : .orange)
        }
    }

    private func editableSlotRow(slot: Binding<EditableSlot>) -> some View {
        let musclesOk = slot.wrappedValue.targetMuscleNames.allSatisfy { MuscleGroup(rawValue: $0) != nil }
        let exOk: Bool = {
            guard let suggested = slot.wrappedValue.suggestedExerciseName, !suggested.isEmpty else { return true }
            return dataVM.globalExercises.contains { $0.name.caseInsensitiveCompare(suggested) == .orderedSame }
        }()
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Slot label", text: slot.label)
                    .font(.body)
                TextField("Target muscles (comma-separated)", text: Binding(
                    get: { slot.wrappedValue.targetMuscleNames.joined(separator: ", ") },
                    set: { slot.wrappedValue.targetMuscleNames = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                ))
                .font(.caption)
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
            }
            Spacer()
            Image(systemName: (musclesOk && exOk) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle((musclesOk && exOk) ? .green : .orange)
        }
    }

    @ViewBuilder
    private var unresolvedNamesSection: some View {
        let unresolved = editableDays.flatMap { day -> [String] in
            var names: [String] = []
            for ex in day.exercises where !dataVM.globalExercises.contains(where: { $0.name.caseInsensitiveCompare(ex.name) == .orderedSame }) {
                if !ex.name.isEmpty { names.append(ex.name) }
            }
            for slot in day.slots {
                for m in slot.targetMuscleNames where MuscleGroup(rawValue: m) == nil { names.append(m) }
                if let s = slot.suggestedExerciseName, !s.isEmpty,
                   !dataVM.globalExercises.contains(where: { $0.name.caseInsensitiveCompare(s) == .orderedSame }) {
                    names.append(s)
                }
            }
            return names
        }
        let unique = Set(unresolved).sorted()
        if !unique.isEmpty {
            Section {
                Text("Not found in your library (will be skipped when applying): \(unique.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } header: {
                Text("Unmatched names")
            }
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
                WorkoutSplitProposalExerciseItem(name: $0.name, sets: $0.sets, reps: $0.reps)
            }
            let slots = day.slots.map {
                WorkoutSplitProposalSlotItem(label: $0.label, targetMuscleNames: $0.targetMuscleNames, sets: $0.sets, reps: $0.reps, suggestedExerciseName: $0.suggestedExerciseName)
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

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
