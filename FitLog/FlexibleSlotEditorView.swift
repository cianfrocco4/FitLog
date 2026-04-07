//
//  FlexibleSlotEditorView.swift
//  FitLog
//
//  Editor for one open slot (flexible row) inside a library workout.
//

import SwiftUI

struct FlexibleSlotEditorView: View {
    @EnvironmentObject var dataVM: DataManager
    let workoutId: UUID
    let slotId: UUID
    /// When true (e.g. just added open slot), focus the label field after load.
    var autoFocusLabelOnAppear: Bool = false

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
        guard let w = dataVM.workout(id: workoutId) else { return nil }
        return dataVM.flexibleSlots(from: w).first { $0.id == slotId }
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
                if autoFocusLabelOnAppear {
                    DispatchQueue.main.async {
                        labelFieldFocused = true
                    }
                }
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
            Text("If set, starting a workout prefills this slot with that exercise. You can still change it before or during the session.")
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
        guard let slot = currentSlot else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        var s = slot
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
        dataVM.updateFlexibleSlot(workoutId: workoutId, slot: s)
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
