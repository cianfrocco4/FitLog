//
//  SlotTemplatePlanView.swift
//  FitLog
//
//  Editor for a slot-based blueprint (Option A). Full slot CRUD can grow here.
//

import SwiftUI

struct SlotTemplatePlanView: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    let templateId: UUID

    @State private var slots: [TemplateSlot] = []
    @State private var showRenameAlert = false
    @State private var newTemplateName = ""

    private var canonical: WorkoutTemplate? {
        dataVM.slotTemplate(id: templateId)
    }

    /// Matches `WorkoutPlanView`’s Stop detection: session was started from this slot template.
    private var isThisTemplateSessionActive: Bool {
        guard let s = currentVM.currentSession, s.endTime == nil else { return false }
        return s.sessionPlanOrigin == .slotTemplate(templateId)
    }

    private var canStartSlotTemplate: Bool {
        !(canonical?.slots.isEmpty ?? true)
    }

    var body: some View {
        templateRoot
            .navigationTitle(canonical?.name ?? "Template")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isThisTemplateSessionActive ? "Stop" : "Start") {
                        if isThisTemplateSessionActive {
                            currentVM.stopWorkout()
                        } else {
                            startWorkoutFromTemplate()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isThisTemplateSessionActive ? .red : .green)
                    .disabled(!isThisTemplateSessionActive && !canStartSlotTemplate)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Rename") {
                        newTemplateName = canonical?.name ?? ""
                        showRenameAlert = true
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .onAppear {
                syncFromData()
            }
            .onChange(of: dataVM.userWorkoutTemplates) { _, _ in
                syncFromData()
            }
            .alert("Rename Template", isPresented: $showRenameAlert) {
                TextField("New name", text: $newTemplateName)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    if let t = canonical {
                        dataVM.renameSlotTemplate(t, newName: newTemplateName)
                    }
                }
            }
    }

    @ViewBuilder
    private var templateRoot: some View {
        if canonical == nil {
            ContentUnavailableView("Template removed", systemImage: "tray")
        } else {
            List {
                templateSlotsSection
            }
        }
    }

    private var templateSlotsSection: some View {
        Section {
            if slots.isEmpty {
                Text("No slots yet — add one to define this template.")
                    .foregroundStyle(.secondary)
            }
            ForEach(slots) { slot in
                NavigationLink {
                    TemplateSlotEditorView(templateId: templateId, slotId: slot.id)
                        .environmentObject(dataVM)
                } label: {
                    slotRowLabel(slot)
                }
            }
            .onDelete(perform: deleteSlots)
            .onMove(perform: moveSlots)

            Button("Add slot") {
                addSlot()
            }
        } header: {
            Text("Slots")
        } footer: {
            Text("Flexible template · tap a slot to edit. Use Start / Stop in the toolbar to begin. Unfilled slots become placeholders until you pick exercises.")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func slotRowLabel(_ slot: TemplateSlot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(slot.label)
                .font(.headline)
            Text(slot.targetedMuscles.prefix(3).map(\.rawValue).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func startWorkoutFromTemplate() {
        guard let t = canonical, !t.slots.isEmpty else { return }
        let sessionWorkout = dataVM.instantiateWorkout(from: t)
        currentVM.startWorkout(sessionWorkout, sessionPlanOrigin: .slotTemplate(t.id))
    }

    private func syncFromData() {
        guard let t = dataVM.slotTemplate(id: templateId) else { return }
        slots = t.slots
    }

    private func persistSlots() {
        guard var t = dataVM.slotTemplate(id: templateId) else { return }
        t.slots = slots
        dataVM.updateSlotTemplate(t)
    }

    private func addSlot() {
        let n = slots.count + 1
        slots.append(
            TemplateSlot(
                label: "Slot \(n)",
                targetedMuscles: [.chest],
                exerciseRole: .compound,
                movementPattern: .horizontalPush,
                defaultExerciseId: nil,
                defaultRestTime: 90,
                recommendedSets: 3,
                recommendedReps: "8-12"
            )
        )
        persistSlots()
    }

    private func deleteSlots(at offsets: IndexSet) {
        slots.remove(atOffsets: offsets)
        persistSlots()
    }

    private func moveSlots(from source: IndexSet, to destination: Int) {
        slots.move(fromOffsets: source, toOffset: destination)
        persistSlots()
    }
}

// MARK: - Per-slot editor

private struct TemplateSlotEditorView: View {
    @EnvironmentObject var dataVM: DataManager
    let templateId: UUID
    let slotId: UUID

    @State private var label: String = ""
    @State private var selectedMuscles: [MuscleGroup] = []
    @State private var exerciseRole: ExerciseRole?
    @State private var movementPattern: MovementPattern?
    @State private var defaultExerciseId: UUID?
    @State private var defaultRestTime: Int = 90
    @State private var recommendedSets: Int = 3
    @State private var recommendedReps: String = "8-12"
    @State private var showMusclePicker = false
    @State private var showExercisePicker = false
    @FocusState private var labelFieldFocused: Bool

    private var availableMuscles: [MuscleGroup] {
        MuscleGroup.displayOrder.filter { !selectedMuscles.contains($0) }
    }

    private var currentSlot: TemplateSlot? {
        guard let t = dataVM.slotTemplate(id: templateId) else { return nil }
        return t.slots.first { $0.id == slotId }
    }

    private var defaultExerciseButtonTitle: String {
        guard let id = defaultExerciseId,
              let ex = dataVM.globalExercises.first(where: { $0.id == id }) else {
            return "None — choose when training"
        }
        return dataVM.resolvedDisplayName(for: ex)
    }

    var body: some View {
        slotEditorChrome
            .onAppear {
                loadFromCanonical()
            }
            .sheet(isPresented: $showMusclePicker) {
                musclePickerSheet
            }
            .sheet(isPresented: $showExercisePicker) {
                DefaultExercisePickerSheet(selectedExerciseId: $defaultExerciseId)
                    .environmentObject(dataVM)
                    .onDisappear {
                        persistFromState()
                    }
            }
    }

    @ViewBuilder
    private var slotEditorChrome: some View {
        if currentSlot == nil {
            ContentUnavailableView("Slot removed", systemImage: "tray")
                .navigationTitle("Edit slot")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            slotEditorForm
                .navigationTitle("Edit slot")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var slotEditorForm: some View {
        Form {
            slotLabelSection
            slotMusclesSection
            slotMetadataSection
            slotDefaultExerciseSection
            slotPrescriptionSection
        }
    }

    private var slotLabelSection: some View {
        Section("Slot") {
            TextField("Label", text: $label)
                .focused($labelFieldFocused)
                .submitLabel(.done)
                .onSubmit { persistFromState() }
                .onChange(of: labelFieldFocused) { _, focused in
                    if !focused { persistFromState() }
                }
        }
    }

    private var slotMusclesSection: some View {
        Section("Muscle groups (up to 3, in order)") {
            ForEach(selectedMuscles.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                    Text(selectedMuscles[index].rawValue)
                    Spacer()
                    Button(role: .destructive) {
                        selectedMuscles.remove(at: index)
                        persistFromState()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                    }
                }
            }
            if selectedMuscles.count < 3 {
                Button {
                    showMusclePicker = true
                } label: {
                    Label("Add muscle group", systemImage: "plus.circle")
                }
            }
        }
    }

    private var slotMetadataSection: some View {
        Section("Optional metadata") {
            Picker("Exercise role", selection: $exerciseRole) {
                Text("Not set").tag(nil as ExerciseRole?)
                ForEach(ExerciseRole.allCases) { role in
                    Text(role.rawValue).tag(Optional(role))
                }
            }
            .onChange(of: exerciseRole) { _, _ in persistFromState() }

            Picker("Movement pattern", selection: $movementPattern) {
                Text("Not set").tag(nil as MovementPattern?)
                ForEach(MovementPattern.allCases) { pattern in
                    Text(pattern.rawValue).tag(Optional(pattern))
                }
            }
            .onChange(of: movementPattern) { _, _ in persistFromState() }
        }
    }

    private var slotDefaultExerciseSection: some View {
        Section {
            Button {
                showExercisePicker = true
            } label: {
                HStack {
                    Text("Default exercise")
                    Spacer()
                    Text(defaultExerciseButtonTitle)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        } footer: {
            Text("If set, starting a workout from this template prefills this slot with that exercise. You can still change it before or during the session.")
                .font(.caption)
        }
    }

    private var slotPrescriptionSection: some View {
        Section("Prescription") {
            Stepper("Rest: \(defaultRestTime) sec", value: $defaultRestTime, in: 0...600, step: 15)
                .onChange(of: defaultRestTime) { _, _ in persistFromState() }
            Stepper("Sets: \(recommendedSets)", value: $recommendedSets, in: 1...10)
                .onChange(of: recommendedSets) { _, _ in persistFromState() }
            TextField("Reps (e.g. 8-12)", text: $recommendedReps)
                .onChange(of: recommendedReps) { _, _ in persistFromState() }
        }
    }

    private var musclePickerSheet: some View {
        NavigationStack {
            List(availableMuscles) { mg in
                Button(mg.rawValue) {
                    selectedMuscles.append(mg)
                    showMusclePicker = false
                    persistFromState()
                }
            }
            .navigationTitle("Muscle group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showMusclePicker = false }
                }
            }
        }
    }

    private func loadFromCanonical() {
        guard let slot = currentSlot else { return }
        label = slot.label
        selectedMuscles = slot.targetedMuscles
        exerciseRole = slot.exerciseRole
        movementPattern = slot.movementPattern
        defaultExerciseId = slot.defaultExerciseId
        defaultRestTime = slot.defaultRestTime
        recommendedSets = slot.recommendedSets
        recommendedReps = slot.recommendedReps
    }

    private func persistFromState() {
        guard var t = dataVM.slotTemplate(id: templateId),
              let idx = t.slots.firstIndex(where: { $0.id == slotId }) else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var s = t.slots[idx]
        if trimmed.isEmpty {
            s.label = s.label.isEmpty ? "Untitled slot" : s.label
        } else {
            s.label = trimmed
        }
        let muscles = selectedMuscles.isEmpty ? [MuscleGroup.other] : Array(selectedMuscles.prefix(3))
        s.targetedMuscles = muscles
        s.exerciseRole = exerciseRole
        s.movementPattern = movementPattern
        s.defaultExerciseId = defaultExerciseId
        s.defaultRestTime = min(max(0, defaultRestTime), 600)
        s.recommendedSets = min(max(1, recommendedSets), 10)
        let repsTrimmed = recommendedReps.trimmingCharacters(in: .whitespacesAndNewlines)
        s.recommendedReps = repsTrimmed.isEmpty ? "8-12" : repsTrimmed
        t.slots[idx] = s
        dataVM.updateSlotTemplate(t)
    }
}

private struct DefaultExercisePickerSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExerciseId: UUID?
    @State private var search = ""

    private var filteredExercises: [Exercise] {
        let sorted = dataVM.globalExercises.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return sorted }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button("None — choose when training") {
                    selectedExerciseId = nil
                    dismiss()
                }
                ForEach(filteredExercises) { ex in
                    Button {
                        selectedExerciseId = ex.id
                        dismiss()
                    } label: {
                        Text(dataVM.resolvedDisplayName(for: ex))
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Default exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
