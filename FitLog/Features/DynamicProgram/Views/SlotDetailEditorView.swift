//
//  SlotDetailEditorView.swift
//  FitLog
//
//  Rich editor for a single template slot (scheme, grouping, rest, notes, substitutions).
//

import SwiftUI

struct SlotDetailEditorView: View {
    @Binding var slot: SplitBuilderEditableSlot
    let partnerCandidates: [SlotGroupingEditorView.PartnerCandidate]
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var showLibraryPicker = false
    @State private var showSubstitutionPicker = false
    @State private var equipmentDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    Button {
                        showLibraryPicker = true
                    } label: {
                        Label(
                            slot.suggestedExerciseName ?? "Pick from library",
                            systemImage: "figure.strengthtraining.traditional"
                        )
                    }
                    .accessibilityHint("Opens searchable exercises scored for this slot.")

                    Toggle("Warm-up slot", isOn: Binding(
                        get: { slot.isWarmUp },
                        set: { v in var s = slot; s.isWarmUp = v; slot = s }
                    ))
                    .accessibilityHint("Marks this row as warm-up work before heavier sets.")
                }

                Section("Prescription") {
                    SetSchemePickerView(scheme: Binding(
                        get: { slot.setScheme },
                        set: { slot.setScheme = $0 }
                    ))
                    Stepper(
                        "Sets: \(slot.sets)",
                        value: Binding(
                            get: { slot.sets },
                            set: { slot = slot.updatingSets($0) }
                        ),
                        in: 1 ... 20
                    )
                    .accessibilityLabel("Working sets")
                    TextField("Reps", text: Binding(get: { slot.reps }, set: { var s = slot; s.reps = $0; slot = s }))
                        .accessibilityLabel("Reps prescription")
                    Stepper(
                        value: Binding(
                            get: { slot.restSeconds ?? 90 },
                            set: { v in var s = slot; s.restSeconds = v; slot = s }
                        ),
                        in: 0 ... 600,
                        step: 15
                    ) {
                        Text("Rest: \(slot.restSeconds ?? 90)s")
                    }
                    .accessibilityLabel("Rest between sets in seconds")
                }

                Section("Grouping") {
                    SlotGroupingEditorView(
                        grouping: Binding(
                            get: { slot.grouping },
                            set: { slot.grouping = $0 }
                        ),
                        currentSlotId: slot.id,
                        partnerCandidates: partnerCandidates
                    )
                }

                Section("Progression override") {
                    Picker("Rule", selection: Binding(
                        get: { slot.progressionRule?.kind ?? .inheritFromBlock },
                        set: { newKind in
                            if newKind == .inheritFromBlock {
                                slot.progressionRule = nil
                            } else if newKind == .linearWeightStep {
                                slot.progressionRule = SlotProgressionRule(kind: .linearWeightStep, weightIncrementKg: slot.progressionRule?.weightIncrementKg ?? 2.5)
                            } else {
                                slot.progressionRule = SlotProgressionRule(kind: newKind, weightIncrementKg: nil)
                            }
                        }
                    )) {
                        Text("Use block default").tag(SlotProgressionKind.inheritFromBlock)
                        Text("Linear +kg").tag(SlotProgressionKind.linearWeightStep)
                        Text("Double progression").tag(SlotProgressionKind.doubleProgression)
                        Text("Wave loading").tag(SlotProgressionKind.waveLoading)
                        Text("Undulating").tag(SlotProgressionKind.undulatingMicrocycle)
                    }
                    .accessibilityHint("Overrides the block’s progression style for this slot.")

                    if slot.progressionRule?.kind == .linearWeightStep {
                        Stepper(
                            "Add per week: \(String(format: "%.1f", slot.progressionRule?.weightIncrementKg ?? 2.5)) kg",
                            value: Binding(
                                get: { slot.progressionRule?.weightIncrementKg ?? 2.5 },
                                set: { v in slot.progressionRule = SlotProgressionRule(kind: .linearWeightStep, weightIncrementKg: v) }
                            ),
                            in: 0.5 ... 10,
                            step: 0.5
                        )
                        .accessibilityLabel("Linear weight increment per week in kilograms")
                    }
                }

                Section("Coaching") {
                    TextField("Notes / cues", text: Binding(
                        get: { slot.notes ?? "" },
                        set: { v in var s = slot; s.notes = v.isEmpty ? nil : v; slot = s }
                    ), axis: .vertical)
                    .lineLimit(2 ... 6)
                    .accessibilityLabel("Coaching notes")

                    TextField("Equipment tags (comma-separated)", text: $equipmentDraft)
                        .onAppear { equipmentDraft = (slot.equipmentTags ?? []).joined(separator: ", ") }
                        .onChange(of: equipmentDraft) { _, raw in
                            let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            var s = slot
                            s.equipmentTags = parts.isEmpty ? nil : parts
                            slot = s
                        }
                        .accessibilityLabel("Equipment tags")
                        .accessibilityHint("Comma-separated tags like cable, dumbbell.")
                }

                Section("Substitutions") {
                    if let subs = slot.substitutionExerciseIds, !subs.isEmpty {
                        ForEach(subs, id: \.self) { sid in
                            HStack {
                                Text(dataManager.globalExercises.first { $0.id == sid }?.name ?? "\(String(sid.uuidString.prefix(6)))…")
                                Spacer()
                                Button(role: .destructive) {
                                    var s = slot
                                    s.substitutionExerciseIds = subs.filter { $0 != sid }
                                    if s.substitutionExerciseIds?.isEmpty == true { s.substitutionExerciseIds = nil }
                                    slot = s
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .accessibilityLabel("Remove substitution")
                            }
                        }
                    }
                    Button {
                        showSubstitutionPicker = true
                    } label: {
                        Label("Add substitution exercise", systemImage: "plus.circle")
                    }
                    .accessibilityHint("Pick an alternative exercise the athlete may swap in.")
                }
            }
            .navigationTitle("Slot details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .accessibilityHint("Closes slot details and keeps your edits.")
                }
            }
            .sheet(isPresented: $showLibraryPicker) {
                ExerciseSlotPickerSheet(slot: slot) { ex in
                    var s = slot
                    s.suggestedExerciseName = ex.name
                    s.suggestedExerciseOverrideId = ex.id
                    s.targetMuscleNames = ex.targetedMuscles.map(\.rawValue)
                    if s.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        s.label = ex.name
                    }
                    slot = s
                    showLibraryPicker = false
                }
                .environment(dataManager)
                .environmentObject(aiService)
            }
            .sheet(isPresented: $showSubstitutionPicker) {
                ExerciseSlotPickerSheet(slot: slot) { ex in
                    var s = slot
                    var list = s.substitutionExerciseIds ?? []
                    if !list.contains(ex.id) { list.append(ex.id) }
                    s.substitutionExerciseIds = list
                    slot = s
                    showSubstitutionPicker = false
                }
                .environment(dataManager)
                .environmentObject(aiService)
            }
        }
    }
}
