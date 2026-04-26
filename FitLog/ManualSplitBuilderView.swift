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
    @EnvironmentObject private var dataVM: DataManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection

    @State private var preset: SplitBuilderManualPreset = .pushPullLegs
    @State private var sessionsPerWeek = 4
    @State private var selectedWeekdays: Set<Int> = []
    @State private var updateTrainingProgram = true
    @State private var step: ManualSplitStep = .setup
    @State private var editableDays: [SplitBuilderEditableDay] = []
    @State private var expandedDayIds: Set<UUID> = []
    @State private var isApplying = false
    @State private var showApplySuccess = false
    @State private var applySuccessMessage = ""

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

    private var warnings: [SplitProposalProgramWarning] {
        SplitProposalProgramAnalyzer.warnings(
            stats: stats,
            days: analyzerDays,
            context: SplitProposalProgramAnalyzer.Context(
                primaryGoal: "Manual split",
                experienceLevel: "Intermediate",
                sessionDurationMinutes: nil,
                priorityNotes: ""
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
                        Text("Sessions per week is capped by selected days.")
                    }
                }
                .font(.caption)
            }

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

    private var editorView: some View {
        List {
            statsSection
            warningsSection
            daysSection
            applySection
        }
        .environment(\.editMode, .constant(.active))
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
            LabeledContent(
                "Push / pull / legs",
                value: "\(stats.pushOrientedSets) / \(stats.pullOrientedSets) / \(stats.legOrientedSets)"
            )
        } header: {
            Text("Program snapshot")
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
            }
        } header: {
            Text("Training days")
        }
    }

    @ViewBuilder
    private var applySection: some View {
        Section {
            Button {
                Task { await apply() }
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
            manualSlotRow(slot: bindingForSlot(day: day, slotId: slotValue.id))
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

    private func manualSlotRow(slot: Binding<SplitBuilderEditableSlot>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Slot label", text: slot.label)
                .font(.body)
            TextField("Default exercise (optional)", text: Binding(
                get: { slot.wrappedValue.suggestedExerciseName ?? "" },
                set: { raw in
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    var next = slot.wrappedValue
                    next.suggestedExerciseName = trimmed.isEmpty ? nil : trimmed
                    next.suggestedExerciseOverrideId = nil
                    if let resolved = ExerciseNameResolution.resolve(planName: trimmed, library: dataVM.globalExercises),
                       case .linked(let ex) = resolved {
                        next.suggestedExerciseOverrideId = ex.id
                        if next.targetMuscleNames == [MuscleGroup.other.rawValue] {
                            next.targetMuscleNames = ex.targetedMuscles.map(\.rawValue)
                        }
                    }
                    slot.wrappedValue = next
                }
            ))
            .font(.caption)
            .textFieldStyle(.roundedBorder)

            Text(muscleSummary(slot.wrappedValue))
                .font(.caption2)
                .foregroundStyle(.secondary)

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
            library: dataVM.globalExercises
        )
        expandedDayIds = Set(editableDays.map(\.id))
        step = .editor
    }

    @MainActor
    private func apply() async {
        isApplying = true
        defer { isApplying = false }

        let effectiveSessions = min(sessionsPerWeek, maxSessionsAllowed)
        let p = SplitBuilderApplyService.apply(
            days: editableDays,
            dataVM: dataVM,
            sessionsPerWeek: effectiveSessions,
            preferredWeekdays: Array(selectedWeekdays).sorted(),
            updateTrainingProgram: updateTrainingProgram,
            rationale: "Manual split built in FitLog."
        )
        let planLine = updateTrainingProgram
            ? "Your Plan tab now follows this cycle."
            : "Your Plan calendar was not changed; new templates are in your workout list."
        applySuccessMessage = "Created \(p.workouts.count) workout template\(p.workouts.count == 1 ? "" : "s"). \(planLine)"
        showApplySuccess = true
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
                    } else if selectedWeekdays.count < sessionsPerWeek {
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
}
