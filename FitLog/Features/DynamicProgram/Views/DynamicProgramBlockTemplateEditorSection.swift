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
    /// Called after structural edits (move / add / remove day or slot).
    let onStructuralChange: () -> Void
    /// Called after slot field edits (sets, label, reps).
    let onSlotFieldChange: () -> Void

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
    }

    @ViewBuilder
    private func templateDayEditor(day: Binding<SplitBuilderEditableDay>) -> some View {
        TextField("Day name", text: day.name)
            .font(.headline)
            .accessibilityLabel("Day name")
        TextField("Focus", text: day.focus)
            .font(.caption)
            .accessibilityLabel("Day focus")

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
            TextField("Slot label", text: Binding(
                get: { slotBinding.wrappedValue.label },
                set: { var s = slotBinding.wrappedValue; s.label = $0; slotBinding.wrappedValue = s }
            ))
            .accessibilityLabel("Slot label")
            Stepper("Sets: \(slotBinding.wrappedValue.sets)", value: Binding(
                get: { slotBinding.wrappedValue.sets },
                set: { var s = slotBinding.wrappedValue; s.sets = $0; slotBinding.wrappedValue = s }
            ), in: 1 ... 10)
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
}
