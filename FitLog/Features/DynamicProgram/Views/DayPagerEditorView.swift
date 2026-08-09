//
//  DayPagerEditorView.swift
//  FitLog
//
//  Horizontal day tabs with tap-to-open slot editing.
//

import SwiftUI

struct DayPagerEditorView: View {
    @Binding var days: [SplitBuilderEditableDay]
    var enableManualSlotChrome: Bool
    var preferredDayIndex: Int? = nil
    let onStructuralChange: () -> Void
    let onSlotFieldChange: () -> Void
    /// Called before a structural mutation so the host can snapshot undo state.
    var onBeforeStructuralChange: (() -> Void)? = nil
    /// Called after a confirmed slot removal (for undo banner messaging).
    var onSlotRemoved: ((String) -> Void)? = nil

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var aiService: AIService

    @State private var selectedDayIndex = 0
    @State private var slotDetailTarget: SlotEditorTarget?
    @State private var slotPendingRemoval: SlotEditorTarget?
    @State private var showRemoveConfirm = false

    private struct SlotEditorTarget: Identifiable, Hashable {
        let dayId: UUID
        let slotId: UUID
        var id: String { "\(dayId.uuidString)|\(slotId.uuidString)" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if days.isEmpty {
                emptyDaysPlaceholder
            } else {
                dayTabBar
                if days.indices.contains(selectedDayIndex) {
                    dayEditorContent(day: $days[selectedDayIndex])
                }
            }
        }
        .sheet(item: $slotDetailTarget, onDismiss: {
            onSlotFieldChange()
        }) { target in
            slotDetailSheet(for: target)
        }
        .alert("Remove this slot?", isPresented: $showRemoveConfirm, presenting: slotPendingRemoval) { target in
            Button("Cancel", role: .cancel) {
                slotPendingRemoval = nil
            }
            Button("Remove", role: .destructive) {
                removeSlot(target)
                slotPendingRemoval = nil
            }
        } message: { target in
            Text(removeConfirmMessage(for: target))
        }
        .onChange(of: days.count) { _, count in
            if selectedDayIndex >= count {
                selectedDayIndex = max(0, count - 1)
            }
        }
        .onAppear {
            if let preferred = preferredDayIndex, days.indices.contains(preferred) {
                selectedDayIndex = preferred
            }
        }
        .onChange(of: preferredDayIndex) { _, preferred in
            guard let preferred, days.indices.contains(preferred) else { return }
            selectedDayIndex = preferred
        }
    }

    private var emptyDaysPlaceholder: some View {
        ContentUnavailableView {
            Label("No training days", systemImage: "calendar.badge.plus")
        } description: {
            Text("Add a day to start building your rotation.")
        } actions: {
            Button("Add day") { appendDay() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var dayTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    Button {
                        selectedDayIndex = index
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.name.isEmpty ? "Day \(index + 1)" : day.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text("\(day.slots.count) slots")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectedDayIndex == index ? Color.accentColor.opacity(0.16) : FitlogPalette.subtleFill)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.name.isEmpty ? "Day \(index + 1)" : day.name), \(day.slots.count) slots")
                    .accessibilityAddTraits(selectedDayIndex == index ? .isSelected : [])
                }

                Button {
                    appendDay()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add day")
                .accessibilityHint("Adds another rotation day")
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func dayEditorContent(day: Binding<SplitBuilderEditableDay>) -> some View {
        DayVolumeIndicatorView(day: day.wrappedValue)

        TextField("Day name", text: day.name)
            .font(.headline)
            .accessibilityLabel("Day name")
            .onChange(of: day.wrappedValue.name) { _, _ in
                onSlotFieldChange()
            }

        TextField("Focus", text: day.focus)
            .font(.caption)
            .accessibilityLabel("Day focus")
            .onChange(of: day.wrappedValue.focus) { _, _ in
                onSlotFieldChange()
            }

        if day.wrappedValue.slots.isEmpty {
            Text("No slots yet — add strength or cardio work below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            ForEach(day.wrappedValue.slots) { slot in
                slotRow(day: day, slotId: slot.id)
            }
            .onMove { from, to in
                onBeforeStructuralChange?()
                var d = day.wrappedValue
                d.slots.move(fromOffsets: from, toOffset: to)
                day.wrappedValue = d
                onStructuralChange()
            }
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

    @ViewBuilder
    private func slotRow(day: Binding<SplitBuilderEditableDay>, slotId: UUID) -> some View {
        if let slotBinding = bindingForSlot(day: day, slotId: slotId) {
            let slot = slotBinding.wrappedValue
            let title = slot.label.isEmpty ? "Untitled slot" : slot.label
            HStack(spacing: 4) {
                Button {
                    slotDetailTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(slot.sets)×\(slot.reps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let exercise = slot.suggestedExerciseName, !exercise.isEmpty {
                                Text(exercise)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title), \(slot.sets) sets")
                .accessibilityHint("Opens the slot editor")

                Button {
                    slotPendingRemoval = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
                    showRemoveConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(title)")
                .accessibilityHint("Asks for confirmation before removing this slot from the day")
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(slot.modality == .cardio
                        ? FitlogPalette.chartSecondary.opacity(0.08)
                        : FitlogPalette.subtleFill)
            )
            .contextMenu {
                Button {
                    slotDetailTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                Button(role: .destructive) {
                    slotPendingRemoval = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
                    showRemoveConfirm = true
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func slotDetailSheet(for target: SlotEditorTarget) -> some View {
        if let day = days.first(where: { $0.id == target.dayId }),
           let slotBinding = bindingForSlot(dayId: target.dayId, slotId: target.slotId, in: day) {
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

    private func appendDay() {
        onBeforeStructuralChange?()
        days.append(SplitBuilderEditableDay(name: "Day \(days.count + 1)", focus: "", slots: []))
        selectedDayIndex = max(0, days.count - 1)
        onStructuralChange()
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
        slotDetailTarget = SlotEditorTarget(dayId: d.id, slotId: slot.id)
    }

    private func appendCardioSlot(to day: Binding<SplitBuilderEditableDay>) {
        onBeforeStructuralChange?()
        var d = day.wrappedValue
        let slot = CardioProgramTemplates.defaultCardioSlot(library: dataManager.globalExercises)
        d.slots.append(slot)
        day.wrappedValue = d
        onStructuralChange()
        slotDetailTarget = SlotEditorTarget(dayId: d.id, slotId: slot.id)
    }

    private func removeSlot(_ target: SlotEditorTarget) {
        guard let dayIndex = days.firstIndex(where: { $0.id == target.dayId }),
              let slotIndex = days[dayIndex].slots.firstIndex(where: { $0.id == target.slotId }) else { return }
        let slot = days[dayIndex].slots[slotIndex]
        let name = slot.suggestedExerciseName ?? (slot.label.isEmpty ? "Slot" : slot.label)
        onBeforeStructuralChange?()
        days[dayIndex].slots.remove(at: slotIndex)
        onStructuralChange()
        onSlotRemoved?(name)
    }

    private func removeConfirmMessage(for target: SlotEditorTarget) -> String {
        guard let day = days.first(where: { $0.id == target.dayId }),
              let slot = day.slots.first(where: { $0.id == target.slotId }) else {
            return "This removes the exercise slot from the day. You can undo afterward."
        }
        let name = slot.suggestedExerciseName ?? (slot.label.isEmpty ? "this slot" : slot.label)
        return "Remove “\(name)” from \(day.name.isEmpty ? "this day" : day.name)? You can undo afterward."
    }

    /// Optional binding — never fabricates a new UUID for a missing slot; refuse id changes on set.
    /// The getter falls back to the last known value so a slot removed while its editor is
    /// still presented cannot trap.
    private func bindingForSlot(day: Binding<SplitBuilderEditableDay>, slotId: UUID) -> Binding<SplitBuilderEditableSlot>? {
        guard let known = day.wrappedValue.slots.first(where: { $0.id == slotId }) else { return nil }
        return Binding(
            get: {
                day.wrappedValue.slots.first(where: { $0.id == slotId }) ?? known
            },
            set: { newSlot in
                guard newSlot.id == slotId,
                      let idx = day.wrappedValue.slots.firstIndex(where: { $0.id == slotId }) else { return }
                day.wrappedValue.slots[idx] = newSlot
            }
        )
    }

    /// Resolves day and slot indices on every access — a captured index would go stale when
    /// days are reordered, removed, or restored by undo while the editor sheet is open.
    private func bindingForSlot(dayId: UUID, slotId: UUID, in day: SplitBuilderEditableDay) -> Binding<SplitBuilderEditableSlot>? {
        guard let known = day.slots.first(where: { $0.id == slotId }) else { return nil }
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

private struct DayVolumeIndicatorView: View {
    let day: SplitBuilderEditableDay

    private var muscleVolumes: [(String, Int)] {
        var totals: [String: Int] = [:]
        for slot in day.slots where slot.modality != .cardio {
            for muscle in slot.targetMuscleNames {
                let key = muscle.capitalized
                totals[key, default: 0] += slot.sets
            }
        }
        return totals.sorted { $0.value > $1.value }.prefix(4).map { ($0.key, $0.value) }
    }

    var body: some View {
        if muscleVolumes.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Volume")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(muscleVolumes, id: \.0) { muscle, sets in
                    HStack(spacing: 8) {
                        Text(muscle)
                            .font(.caption2)
                            .frame(width: 72, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(FitlogPalette.chartPrimary.opacity(0.75))
                                .frame(width: geo.size.width * barScale(for: sets))
                        }
                        .frame(height: 6)
                        Text("\(sets)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Volume by muscle for this day")
        }
    }

    private func barScale(for sets: Int) -> CGFloat {
        let maxSets = max(1, muscleVolumes.map(\.1).max() ?? 1)
        return CGFloat(sets) / CGFloat(maxSets)
    }
}

#Preview {
    @Previewable @State var days: [SplitBuilderEditableDay] = [
        SplitBuilderEditableDay(
            name: "Push",
            focus: "Chest / shoulders",
            slots: [
                SplitBuilderEditableSlot(label: "Bench", targetMuscleNames: ["Chest"], sets: 4, reps: "6-8"),
                SplitBuilderEditableSlot(label: "OHP", targetMuscleNames: ["Shoulders"], sets: 3, reps: "8-10"),
            ]
        ),
    ]
    DayPagerEditorView(
        days: $days,
        enableManualSlotChrome: true,
        onStructuralChange: {},
        onSlotFieldChange: {}
    )
    .padding()
}
