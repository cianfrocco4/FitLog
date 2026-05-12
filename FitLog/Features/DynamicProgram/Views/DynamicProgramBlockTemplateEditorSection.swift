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
    /// When true, shows set-scheme chips, grouping hints, and slot detail / library sheets.
    var enableManualSlotChrome: Bool = false
    /// Called after structural edits (move / add / remove day or slot).
    let onStructuralChange: () -> Void
    /// Called after slot field edits (sets, label, reps).
    let onSlotFieldChange: () -> Void

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var aiService: AIService

    @State private var slotDetailTarget: SlotEditorTarget?
    @State private var slotLibraryTarget: SlotEditorTarget?

    private struct SlotEditorTarget: Identifiable, Hashable {
        let dayId: UUID
        let slotId: UUID
        var id: String { "\(dayId.uuidString)|\(slotId.uuidString)" }
    }

    var body: some View {
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
                days.move(fromOffsets: from, toOffset: to)
                onStructuralChange()
            }

            Button {
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
                SlotDetailEditorView(
                    slot: slotBinding,
                    partnerCandidates: partnerCandidates(for: day, excluding: target.slotId)
                )
                .environment(dataManager)
                .environmentObject(aiService)
            }
        }
        .sheet(item: $slotLibraryTarget) { target in
            if let slotBinding = bindingForSlot(dayId: target.dayId, slotId: target.slotId) {
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
            var d = day.wrappedValue
            d.slots.move(fromOffsets: from, toOffset: to)
            day.wrappedValue = d
            onStructuralChange()
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
            onStructuralChange()
        } label: {
            Label("Add slot", systemImage: "plus.circle")
        }
        .font(.subheadline)
        .accessibilityHint("Adds a new exercise slot to this day")

        if !day.wrappedValue.slots.isEmpty {
            Button(role: .destructive) {
                var d = day.wrappedValue
                d.slots.removeLast()
                day.wrappedValue = d
                onStructuralChange()
            } label: {
                Label("Remove last slot", systemImage: "minus.circle")
            }
            .font(.subheadline)
            .accessibilityHint("Removes the last slot from this day")
        }
    }

    private func templateSlotRow(day: Binding<SplitBuilderEditableDay>, slotId: UUID) -> some View {
        let slotBinding = Binding<SplitBuilderEditableSlot>(
            get: {
                day.wrappedValue.slots.first(where: { $0.id == slotId })
                    ?? SplitBuilderEditableSlot(label: "", targetMuscleNames: [MuscleGroup.other.rawValue], sets: 3, reps: "8-12")
            },
            set: { newSlot in
                guard let idx = day.wrappedValue.slots.firstIndex(where: { $0.id == slotId }) else { return }
                day.wrappedValue.slots[idx] = newSlot
                onSlotFieldChange()
            }
        )
        return VStack(alignment: .leading, spacing: 8) {
            if enableManualSlotChrome {
                HStack(spacing: 6) {
                    Text((slotBinding.wrappedValue.setScheme ?? SetScheme(kind: .fixed)).displayLabel)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                        .accessibilityLabel("Set scheme \(slotBinding.wrappedValue.setScheme?.displayLabel ?? "Fixed")")

                    if let g = slotBinding.wrappedValue.grouping, g.kind != .standalone, !g.displayLabel.isEmpty {
                        Text(g.displayLabel)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .accessibilityLabel("Grouping \(g.displayLabel)")
                    }

                    if let cue = slotBinding.wrappedValue.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !cue.isEmpty {
                        Text(String(cue.prefix(28)) + (cue.count > 28 ? "…" : ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .accessibilityLabel("Coaching note \(cue)")
                    }
                }
            }

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

            if enableManualSlotChrome {
                HStack(spacing: 10) {
                    Button {
                        slotDetailTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
                    } label: {
                        Label("Details", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("Edit set scheme, grouping, rest, notes, and substitutions.")

                    Button {
                        slotLibraryTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
                    } label: {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint("Search your exercise library to assign this slot.")
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func bindingForSlot(dayId: UUID, slotId: UUID) -> Binding<SplitBuilderEditableSlot>? {
        guard let dIdx = days.firstIndex(where: { $0.id == dayId }),
              days[dIdx].slots.contains(where: { $0.id == slotId }) else { return nil }
        return Binding(
            get: {
                days[dIdx].slots.first(where: { $0.id == slotId })
                    ?? SplitBuilderEditableSlot(label: "", targetMuscleNames: [MuscleGroup.other.rawValue], sets: 3, reps: "8-12")
            },
            set: { newSlot in
                guard let sIdx = days[dIdx].slots.firstIndex(where: { $0.id == slotId }) else { return }
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
