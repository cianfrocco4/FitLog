//
//  DynamicProgramBlockTemplateEditorSection.swift
//  FitLog
//
//  Shared editable rotation templates (days + slots) for the dynamic program
//  preview form and the timeline editor.
//

import SwiftUI

struct DynamicProgramBlockTemplateEditorSection: View {
    @Binding var days: [SplitBuilderEditableDay]
    /// When true, uses day pager + tap-to-open slot editor instead of DisclosureGroups.
    var enableManualSlotChrome: Bool = false
    /// Preferred day index when opening the pager (from balance suggestions).
    var preferredDayIndex: Int? = nil
    /// Called after structural edits (move / add / remove day or slot).
    let onStructuralChange: () -> Void
    /// Called after slot field edits (sets, label, reps).
    let onSlotFieldChange: () -> Void
    /// Called before a structural mutation so the host can snapshot undo state.
    var onBeforeStructuralChange: (() -> Void)? = nil
    /// Called after a confirmed slot removal.
    var onSlotRemoved: ((String) -> Void)? = nil

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var aiService: AIService

    @State private var slotDetailTarget: LegacySlotEditorTarget?
    @State private var slotLibraryTarget: LegacySlotEditorTarget?

    private struct LegacySlotEditorTarget: Identifiable, Hashable {
        let dayId: UUID
        let slotId: UUID
        var id: String { "\(dayId.uuidString)|\(slotId.uuidString)" }
    }

    var body: some View {
        Group {
            if enableManualSlotChrome {
                DayPagerEditorView(
                    days: $days,
                    enableManualSlotChrome: true,
                    preferredDayIndex: preferredDayIndex,
                    onStructuralChange: onStructuralChange,
                    onSlotFieldChange: onSlotFieldChange,
                    onBeforeStructuralChange: onBeforeStructuralChange,
                    onSlotRemoved: onSlotRemoved
                )
            } else {
                legacyDisclosureEditor
            }
        }
    }

    private var legacyDisclosureEditor: some View {
        Group {
            ForEach($days) { $day in
                DisclosureGroup {
                    templateDayEditor(day: $day)
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
            .onMove { from, to in
                onBeforeStructuralChange?()
                days.move(fromOffsets: from, toOffset: to)
                onStructuralChange()
            }

            Button {
                onBeforeStructuralChange?()
                days.append(
                    SplitBuilderEditableDay(
                        name: "Day \(days.count + 1)",
                        focus: "",
                        slots: []
                    )
                )
                onStructuralChange()
            } label: {
                Label("Add day", systemImage: "plus.circle")
            }
            .accessibilityHint("Adds another rotation template to this block")
        }
        .sheet(item: $slotDetailTarget) { target in
            if let day = days.first(where: { $0.id == target.dayId }),
               let slotBinding = bindingForSlot(dayId: target.dayId, slotId: target.slotId) {
                if slotBinding.wrappedValue.modality == .cardio {
                    CardioSlotDetailEditorView(slot: slotBinding)
                        .environment(dataManager)
                } else {
                    SlotDetailEditorView(
                        slot: slotBinding,
                        partnerCandidates: partnerCandidates(for: day, excluding: target.slotId)
                    )
                    .environment(dataManager)
                    .environmentObject(aiService)
                }
            }
        }
        .sheet(item: $slotLibraryTarget) { target in
            if let slotBinding = bindingForSlot(dayId: target.dayId, slotId: target.slotId) {
                if slotBinding.wrappedValue.modality == .cardio {
                    CardioExercisePickerSheet { exercise in
                        var s = slotBinding.wrappedValue
                        s.suggestedExerciseName = exercise.name
                        s.suggestedExerciseOverrideId = exercise.id
                        s.targetMuscleNames = exercise.targetedMuscles.map(\.rawValue)
                        if s.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            s.label = exercise.name
                        }
                        slotBinding.wrappedValue = s
                        onSlotFieldChange()
                        slotLibraryTarget = nil
                    }
                    .environment(dataManager)
                } else {
                    ExerciseSlotPickerSheet(slot: slotBinding.wrappedValue) { exercise in
                        var s = slotBinding.wrappedValue
                        s.suggestedExerciseName = exercise.name
                        s.suggestedExerciseOverrideId = exercise.id
                        s.targetMuscleNames = exercise.targetedMuscles.map(\.rawValue)
                        if s.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            s.label = exercise.name
                        }
                        slotBinding.wrappedValue = s
                        onSlotFieldChange()
                        slotLibraryTarget = nil
                    }
                    .environment(dataManager)
                    .environmentObject(aiService)
                }
            }
        }
    }

    @ViewBuilder
    private func templateDayEditor(day: Binding<SplitBuilderEditableDay>) -> some View {
        TextField("Day name", text: day.name)
            .font(.headline)
            .accessibilityLabel("Day name")
        TextField("Focus", text: day.focus)
            .font(.caption)
            .accessibilityLabel("Day focus")
        TextField("Day notes", text: Binding(
            get: { day.wrappedValue.dayNotes ?? "" },
            set: { v in
                var d = day.wrappedValue
                d.dayNotes = v.isEmpty ? nil : v
                day.wrappedValue = d
                onSlotFieldChange()
            }
        ), axis: .vertical)
        .lineLimit(1 ... 3)
        .font(.caption)
        .accessibilityLabel("Day coaching notes")

        ForEach(day.wrappedValue.slots) { slot in
            templateSlotRow(day: day, slotId: slot.id)
        }
        .onMove { from, to in
            onBeforeStructuralChange?()
            var d = day.wrappedValue
            d.slots.move(fromOffsets: from, toOffset: to)
            day.wrappedValue = d
            onStructuralChange()
        }

        Menu {
            Button { appendStrengthSlot(to: day) } label: {
                Label("Strength slot", systemImage: "figure.strengthtraining.traditional")
            }
            Button { appendCardioSlot(to: day) } label: {
                Label("Cardio slot", systemImage: "figure.run")
            }
        } label: {
            Label("Add slot", systemImage: "plus.circle")
        }
        .font(.subheadline)
        .accessibilityHint("Adds a strength or cardio exercise slot to this day")
    }

    private func appendStrengthSlot(to day: Binding<SplitBuilderEditableDay>) {
        onBeforeStructuralChange?()
        var d = day.wrappedValue
        let slot = SplitBuilderEditableSlot(
            label: "New slot",
            targetMuscleNames: [MuscleGroup.other.rawValue],
            sets: 3,
            reps: "8-12"
        )
        d.slots.append(slot)
        day.wrappedValue = d
        onStructuralChange()
        slotDetailTarget = LegacySlotEditorTarget(dayId: d.id, slotId: slot.id)
    }

    private func appendCardioSlot(to day: Binding<SplitBuilderEditableDay>) {
        onBeforeStructuralChange?()
        var d = day.wrappedValue
        let slot = CardioProgramTemplates.defaultCardioSlot(library: dataManager.globalExercises)
        d.slots.append(slot)
        day.wrappedValue = d
        onStructuralChange()
        slotDetailTarget = LegacySlotEditorTarget(dayId: d.id, slotId: slot.id)
    }

    @ViewBuilder
    private func templateSlotRow(day: Binding<SplitBuilderEditableDay>, slotId: UUID) -> some View {
        if day.wrappedValue.slots.contains(where: { $0.id == slotId }) {
            let slotBinding = Binding<SplitBuilderEditableSlot>(
                get: {
                    day.wrappedValue.slots.first(where: { $0.id == slotId })!
                },
                set: { newSlot in
                    guard newSlot.id == slotId,
                          let idx = day.wrappedValue.slots.firstIndex(where: { $0.id == slotId }) else { return }
                    day.wrappedValue.slots[idx] = newSlot
                    onSlotFieldChange()
                }
            )

            if slotBinding.wrappedValue.modality == .cardio {
                cardioTemplateSlotRow(day: day, slotId: slotId, slotBinding: slotBinding)
            } else {
                strengthTemplateSlotRow(day: day, slotId: slotId, slotBinding: slotBinding)
            }
        }
    }

    private func cardioTemplateSlotRow(
        day: Binding<SplitBuilderEditableDay>,
        slotId: UUID,
        slotBinding: Binding<SplitBuilderEditableSlot>
    ) -> some View {
        let exercise = slotBinding.wrappedValue.suggestedExerciseOverrideId.flatMap { id in
            dataManager.globalExercises.first { $0.id == id }
        }
        let prescription = slotBinding.wrappedValue.cardioPrescription
            ?? CardioPrescription(kind: .steadyState, targetDurationSec: 30 * 60, targetZone: .zone2)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.chartSecondary)
                Text("Cardio")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(FitlogPalette.chartSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(FitlogPalette.chartSecondary.opacity(0.14)))
                Spacer(minLength: 0)
            }
            .accessibilityHidden(true)

            TextField("Slot label", text: Binding(
                get: { slotBinding.wrappedValue.label },
                set: { var s = slotBinding.wrappedValue; s.label = $0; slotBinding.wrappedValue = s }
            ))
            .accessibilityLabel("Cardio slot label")

            CardioPrescriptionRowView(prescription: prescription, exercise: exercise)

            Text(slotBinding.wrappedValue.suggestedExerciseName ?? "Pick a cardio exercise")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(FitlogPalette.chartSecondary.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Cardio slot, \(slotBinding.wrappedValue.label)")
    }

    private func strengthTemplateSlotRow(
        day: Binding<SplitBuilderEditableDay>,
        slotId: UUID,
        slotBinding: Binding<SplitBuilderEditableSlot>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Slot label", text: Binding(
                get: { slotBinding.wrappedValue.label },
                set: { var s = slotBinding.wrappedValue; s.label = $0; slotBinding.wrappedValue = s }
            ))
            .accessibilityLabel("Slot label")
            Stepper("Sets: \(slotBinding.wrappedValue.sets)", value: Binding(
                get: { slotBinding.wrappedValue.sets },
                set: { var s = slotBinding.wrappedValue; s = s.updatingSets($0); slotBinding.wrappedValue = s }
            ), in: 1 ... 20)
            .accessibilityLabel("Sets for slot")
            TextField("Reps (e.g. 8-12)", text: Binding(
                get: { slotBinding.wrappedValue.reps },
                set: { var s = slotBinding.wrappedValue; s.reps = $0; slotBinding.wrappedValue = s }
            ))
            .accessibilityLabel("Reps range")
            Text(slotBinding.wrappedValue.suggestedExerciseName ?? "Exercise from library when saved")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    /// Resolves day and slot indices on every access — a captured index would go stale when
    /// days are reordered, removed, or restored by undo while the editor sheet is open.
    private func bindingForSlot(dayId: UUID, slotId: UUID) -> Binding<SplitBuilderEditableSlot>? {
        guard let known = days.first(where: { $0.id == dayId })?.slots.first(where: { $0.id == slotId }) else {
            return nil
        }
        return Binding(
            get: {
                days.first(where: { $0.id == dayId })?
                    .slots.first(where: { $0.id == slotId }) ?? known
            },
            set: { newSlot in
                guard newSlot.id == slotId,
                      let dIdx = days.firstIndex(where: { $0.id == dayId }),
                      let sIdx = days[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
                days[dIdx].slots[sIdx] = newSlot
                onSlotFieldChange()
            }
        )
    }

    private func partnerCandidates(for day: SplitBuilderEditableDay, excluding slotId: UUID) -> [SlotGroupingEditorView.PartnerCandidate] {
        day.slots
            .filter { $0.id != slotId }
            .map { s in
                let title = s.suggestedExerciseName ?? (s.label.isEmpty ? "Slot" : s.label)
                return SlotGroupingEditorView.PartnerCandidate(id: s.id, label: title)
            }
    }
}
