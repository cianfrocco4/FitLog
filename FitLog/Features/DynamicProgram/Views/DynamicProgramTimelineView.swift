//
//  DynamicProgramTimelineView.swift
//  FitLog
//
//  Block / week / template outline with calendar-anchored week labels and optional
//  inline template editing when a builder view model is provided.
//

import SwiftUI

struct DynamicProgramTimelineView: View {
    let program: DynamicProgram
    let anchorDate: Date
    /// When set, each block can expand to edit rotation templates (shared with the preview form).
    var builderViewModel: DynamicProgramBuilderViewModel?
    /// Called when a balance suggestion requests AI regeneration (the timeline cannot trigger generation itself).
    var onRegenerateRequest: ((String) -> Void)?

    private var calendar: Calendar { .current }

    private var previewState: DynamicProgramState {
        DynamicProgramState(program: program, anchorDate: calendar.startOfDay(for: anchorDate))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Array(program.blocks.enumerated()), id: \.element.id) { blockIndex, block in
                    blockSection(blockIndex: blockIndex, block: block)
                }
            }
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Program timeline, \(program.blocks.count) blocks")
    }

    // MARK: - Sections

    private func blockSection(blockIndex: Int, block: ProgramBlock) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Block \(blockIndex + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(block.name)
                    .font(.headline)
                Spacer(minLength: 0)
                Text("\(block.durationWeeks) wk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Text("Weeks 1–\(block.durationWeeks) · \(block.focus.displayTitle)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .accessibilityLabel("Focus for weeks 1 through \(block.durationWeeks): \(block.focus.displayTitle)")

            if let notes = block.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            rotationSummary(block: block)

            Text("Same rotation each week · \(progressionLabel(block.progressionStrategy))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(1 ... block.durationWeeks, id: \.self) { week in
                    weekRangeRow(blockIndex: blockIndex, block: block, weekIndex: week)
                }
            }

            if let vm = builderViewModel {
                DynamicProgramTimelineBlockEditorSection(viewModel: vm, blockIndex: blockIndex, onRegenerateRequest: onRegenerateRequest)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func rotationSummary(block: ProgramBlock) -> some View {
        let names = block.weeklyTemplates.map(\.dayName).joined(separator: " · ")
        let exercises = allExerciseNames(for: block)
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(block.weeklyTemplates) { day in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.dayName.isEmpty ? "Untitled day" : day.dayName)
                            .font(.caption.weight(.semibold))
                        if !day.focus.isEmpty {
                            Text(day.focus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        let dayExercises = exerciseNames(for: day.slots)
                        Text(dayExercises.isEmpty ? "No exercises yet" : dayExercises.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly rotation")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(names.isEmpty ? "No templates" : names)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !exercises.isEmpty {
                    Text(exercises.prefix(6).joined(separator: ", ") + (exercises.count > 6 ? "…" : ""))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityHint("Shows all exercises in the weekly rotation")
    }

    private func weekRangeRow(blockIndex: Int, block: ProgramBlock, weekIndex: Int) -> some View {
        let weekLabel = weekCalendarLabel(blockIndex: blockIndex, weekIndex1Based: weekIndex)
        return HStack(spacing: 8) {
            Text("Week \(weekIndex)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            if let weekLabel {
                Text(weekLabel)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            if block.isDeloadBlock || block.focus.kind == .deload {
                Text("Deload")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    .accessibilityLabel("Deload week")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Week \(weekIndex)\(weekLabel.map { ", \($0)" } ?? "")\(block.isDeloadBlock || block.focus.kind == .deload ? ", deload week" : "")"
        )
    }

    private func weekCalendarLabel(blockIndex: Int, weekIndex1Based: Int) -> String? {
        let pe = PeriodizationEngine(calendar: calendar)
        let state = previewState
        let week0 = weekIndex1Based - 1
        let blockStart = pe.blockStartDate(blockIndex: blockIndex, state: state)
        guard let weekStart = calendar.date(byAdding: .day, value: week0 * 7, to: blockStart) else { return nil }
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return nil }
        let f = Self.weekRangeFormatter
        return "\(f.string(from: weekStart)) – \(f.string(from: weekEnd))"
    }

    private func allExerciseNames(for block: ProgramBlock) -> [String] {
        block.weeklyTemplates.flatMap { exerciseNames(for: $0.slots) }
    }

    private func exerciseNames(for slots: [SplitBuilderEditableSlot]) -> [String] {
        slots.map { slot -> String in
            if let n = slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                return n
            }
            let lab = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return lab.isEmpty ? "Slot" : lab
        }
    }

    private func progressionLabel(_ strategy: ProgressionStrategy) -> String {
        switch strategy {
        case .linear: return "linear progression"
        case .doubleProgression: return "double progression"
        case .undulating: return "undulating progression"
        case .autoregulated: return "autoregulated progression"
        }
    }

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

// MARK: - Timeline inline editor

private struct DynamicProgramTimelineBlockEditorSection: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    let blockIndex: Int
    var onRegenerateRequest: ((String) -> Void)?

    var body: some View {
        DisclosureGroup {
            DynamicProgramBlockTemplateEditorSection(
                days: viewModel.bindingForBlockDays(blockIndex),
                preferredDayIndex: blockIndex == viewModel.editableBlockIndex ? viewModel.editableDayIndex : nil,
                onStructuralChange: {
                    viewModel.selectEditableBlock(blockIndex)
                    viewModel.commitStructuralEdit()
                },
                onSlotFieldChange: {
                    viewModel.selectEditableBlock(blockIndex)
                    viewModel.commitFieldEdit()
                },
                onBeforeStructuralChange: {
                    viewModel.pushUndoSnapshot()
                },
                onSlotRemoved: { name in
                    viewModel.undoBannerMessage = "Removed “\(name)” — Undo"
                }
            )

            let warns = viewModel.balanceWarningsForBlock(at: blockIndex)
            if !warns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Balance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(warns) { w in
                        BalanceSuggestionRow(warning: w) {
                            viewModel.selectEditableBlock(blockIndex)
                            // Host review screen handles regenerate; timeline opens/adds locally.
                            switch w.suggestion {
                            case .openDay(let day):
                                viewModel.openDayFromSuggestion(dayIndex: day)
                            case .addSlot(let day, let label, let muscles):
                                _ = viewModel.addComplementarySlot(dayIndex: day, label: label, muscles: muscles)
                            case .regenerateWithNote(let note):
                                viewModel.appendRegenerateConstraint(note)
                                onRegenerateRequest?(note)
                            case .addDeloadPhase:
                                _ = viewModel.applyAddDeloadPhase()
                            case .raiseWeeklyVolume(let target):
                                _ = viewModel.applyRaiseWeeklyVolume(targetHardSets: target, blockIndex: blockIndex)
                            case .none:
                                break
                            }
                        }
                    }
                }
                .padding(.top, 6)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Balance suggestions for this block")
            }
        } label: {
            Label("Edit rotation templates", systemImage: "square.and.pencil")
                .font(.subheadline.weight(.semibold))
        }
    }
}

#Preview {
    DynamicProgramTimelineView(
        program: DynamicProgram(
            name: "Preview",
            blocks: [
                ProgramBlock(
                    name: "Build",
                    focus: BlockFocus(kind: .hypertrophy, emphasisLabel: "Upper"),
                    durationWeeks: 4,
                    weeklyTemplates: [
                        BlockWeeklyTemplate(
                            dayName: "Push",
                            focus: "Chest",
                            slots: [
                                SplitBuilderEditableSlot(label: "Bench", targetMuscleNames: ["Chest"], sets: 3, reps: "8-12", suggestedExerciseName: "Barbell Bench Press"),
                                SplitBuilderEditableSlot(label: "OHP", targetMuscleNames: ["Shoulders"], sets: 3, reps: "8-12", suggestedExerciseName: "Overhead Press"),
                            ]
                        ),
                        BlockWeeklyTemplate(
                            dayName: "Pull",
                            focus: "Back",
                            slots: [
                                SplitBuilderEditableSlot(label: "Row", targetMuscleNames: ["Back"], sets: 3, reps: "8-12", suggestedExerciseName: "Barbell Row"),
                            ]
                        ),
                    ],
                    progressionStrategy: .doubleProgression
                ),
            ],
            defaultSessionsPerWeek: 3,
            preferredWeekdays: [2, 4, 6]
        ),
        anchorDate: Date()
    )
    .padding()
}
