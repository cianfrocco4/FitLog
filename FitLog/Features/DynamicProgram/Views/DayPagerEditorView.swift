//
//  DayPagerEditorView.swift
//  FitLog
//
//  Horizontal day tabs with inline expandable slot editing.
//

import SwiftUI

struct DayPagerEditorView: View {
    @Binding var days: [SplitBuilderEditableDay]
    var enableManualSlotChrome: Bool
    let onStructuralChange: () -> Void
    let onSlotFieldChange: () -> Void

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var aiService: AIService

    @State private var selectedDayIndex = 0
    @State private var expandedSlotIds: Set<UUID> = []
    @State private var slotDetailTarget: SlotEditorTarget?

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
        .sheet(item: $slotDetailTarget) { target in
            slotDetailSheet(for: target)
        }
        .onChange(of: days.count) { _, count in
            if selectedDayIndex >= count {
                selectedDayIndex = max(0, count - 1)
            }
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

        TextField("Focus", text: day.focus)
            .font(.caption)
            .accessibilityLabel("Day focus")

        if day.wrappedValue.slots.isEmpty {
            Text("No slots yet — add strength or cardio work below.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            ForEach(day.wrappedValue.slots) { slot in
                inlineSlotCard(day: day, slotId: slot.id)
            }
            .onMove { from, to in
                var d = day.wrappedValue
                d.slots.move(fromOffsets: from, toOffset: to)
                day.wrappedValue = d
                onStructuralChange()
            }
        }

        HStack(spacing: 10) {
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

            if !day.wrappedValue.slots.isEmpty {
                Button(role: .destructive) {
                    var d = day.wrappedValue
                    d.slots.removeLast()
                    day.wrappedValue = d
                    onStructuralChange()
                } label: {
                    Label("Remove last", systemImage: "minus.circle")
                }
                .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private func inlineSlotCard(day: Binding<SplitBuilderEditableDay>, slotId: UUID) -> some View {
        let slotBinding = bindingForSlot(day: day, slotId: slotId)
        let isExpanded = expandedSlotIds.contains(slotId)

        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    if isExpanded {
                        expandedSlotIds.remove(slotId)
                    } else {
                        expandedSlotIds.insert(slotId)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(slotBinding.wrappedValue.label.isEmpty ? "Untitled slot" : slotBinding.wrappedValue.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("\(slotBinding.wrappedValue.sets)×\(slotBinding.wrappedValue.reps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(slotBinding.wrappedValue.label), \(slotBinding.wrappedValue.sets) sets")
            .accessibilityHint(isExpanded ? "Collapse slot details" : "Expand slot details")

            if isExpanded {
                inlineSlotDetails(day: day, slotId: slotId, slotBinding: slotBinding)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(slotBinding.wrappedValue.modality == .cardio
                    ? FitlogPalette.chartSecondary.opacity(0.08)
                    : FitlogPalette.subtleFill)
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                slotDetailTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
            }
        )
        .accessibilityAction(named: "Full editor") {
            slotDetailTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
        }
    }

    @ViewBuilder
    private func inlineSlotDetails(
        day: Binding<SplitBuilderEditableDay>,
        slotId: UUID,
        slotBinding: Binding<SplitBuilderEditableSlot>
    ) -> some View {
        TextField("Slot label", text: Binding(
            get: { slotBinding.wrappedValue.label },
            set: { var s = slotBinding.wrappedValue; s.label = $0; slotBinding.wrappedValue = s; onSlotFieldChange() }
        ))
        .accessibilityLabel("Slot label")

        Stepper("Sets: \(slotBinding.wrappedValue.sets)", value: Binding(
            get: { slotBinding.wrappedValue.sets },
            set: { var s = slotBinding.wrappedValue; s = s.updatingSets($0); slotBinding.wrappedValue = s; onSlotFieldChange() }
        ), in: 1 ... 20)

        TextField("Reps", text: Binding(
            get: { slotBinding.wrappedValue.reps },
            set: { var s = slotBinding.wrappedValue; s.reps = $0; slotBinding.wrappedValue = s; onSlotFieldChange() }
        ))

        Text(slotBinding.wrappedValue.suggestedExerciseName ?? "Exercise assigned when saved")
            .font(.caption)
            .foregroundStyle(.secondary)

        if enableManualSlotChrome {
            Button {
                slotDetailTarget = SlotEditorTarget(dayId: day.wrappedValue.id, slotId: slotId)
            } label: {
                Label("Full editor", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
        days.append(SplitBuilderEditableDay(name: "Day \(days.count + 1)", focus: "", slots: []))
        selectedDayIndex = max(0, days.count - 1)
        onStructuralChange()
    }

    private func appendStrengthSlot(to day: Binding<SplitBuilderEditableDay>) {
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
        if let id = d.slots.last?.id {
            expandedSlotIds.insert(id)
        }
        onStructuralChange()
    }

    private func appendCardioSlot(to day: Binding<SplitBuilderEditableDay>) {
        var d = day.wrappedValue
        d.slots.append(CardioProgramTemplates.defaultCardioSlot(library: dataManager.globalExercises))
        day.wrappedValue = d
        if let id = d.slots.last?.id {
            expandedSlotIds.insert(id)
        }
        onStructuralChange()
    }

    private func bindingForSlot(day: Binding<SplitBuilderEditableDay>, slotId: UUID) -> Binding<SplitBuilderEditableSlot> {
        Binding(
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
    }

    private func bindingForSlot(dayId: UUID, slotId: UUID, in day: SplitBuilderEditableDay) -> Binding<SplitBuilderEditableSlot>? {
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
                SlotGroupingEditorView.PartnerCandidate(
                    id: s.id,
                    label: s.suggestedExerciseName ?? (s.label.isEmpty ? "Slot" : s.label)
                )
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
