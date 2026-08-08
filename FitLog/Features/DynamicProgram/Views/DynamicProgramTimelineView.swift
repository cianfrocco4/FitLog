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

            Text(block.focus.displayTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(1 ... block.durationWeeks, id: \.self) { week in
                weekRow(blockIndex: blockIndex, block: block, weekIndex: week)
            }

            if let vm = builderViewModel {
                DynamicProgramTimelineBlockEditorSection(viewModel: vm, blockIndex: blockIndex)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func weekRow(blockIndex: Int, block: ProgramBlock, weekIndex: Int) -> some View {
        let pe = PeriodizationEngine(calendar: calendar)
        let state = previewState
        let weekLabel = weekCalendarLabel(blockIndex: blockIndex, weekIndex1Based: weekIndex, engine: pe, state: state)
        let names = block.weeklyTemplates.map(\.dayName).joined(separator: " · ")
        let slotLines = block.weeklyTemplates.flatMap(\.slots)
        let exercisePreview = slotLines.prefix(14).map { slot -> String in
            if let n = slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { return n }
            let lab = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return lab.isEmpty ? "Slot" : lab
        }
        let previewText = exercisePreview.joined(separator: ", ")
        let rotationA11y = names.isEmpty ? "No templates" : names
        let exerciseA11y = previewText.isEmpty ? "" : ", exercises: \(previewText)"
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week \(weekIndex)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                if let weekLabel {
                    Text(weekLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 4) {
                Text(names.isEmpty ? "No templates" : names)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Week \(weekIndex)\(weekLabel.map { ", \($0)" } ?? ""), rotation: \(rotationA11y)\(exerciseA11y)")
    }

    private func weekCalendarLabel(blockIndex: Int, weekIndex1Based: Int, engine: PeriodizationEngine, state: DynamicProgramState) -> String? {
        let week0 = weekIndex1Based - 1
        let blockStart = engine.blockStartDate(blockIndex: blockIndex, state: state)
        guard let weekStart = calendar.date(byAdding: .day, value: week0 * 7, to: blockStart) else { return nil }
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else { return nil }
        let f = Self.weekRangeFormatter
        return "\(f.string(from: weekStart)) – \(f.string(from: weekEnd))"
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
                            case .regenerateWithNote, .none:
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
        .accessibilityHint("Expand to edit training day names, slots, and sets for this block")
    }
}

#Preview("Timeline") {
    let block = ProgramBlock(
        name: "Hypertrophy",
        focus: BlockFocus(kind: .hypertrophy, emphasisLabel: "Upper"),
        durationWeeks: 2,
        weeklyTemplates: [
            BlockWeeklyTemplate(dayName: "Push", focus: "Chest", slots: []),
            BlockWeeklyTemplate(dayName: "Pull", focus: "Back", slots: []),
            BlockWeeklyTemplate(dayName: "Legs", focus: "Lower", slots: []),
        ]
    )
    let program = DynamicProgram(
        name: "Sample",
        blocks: [block],
        defaultSessionsPerWeek: 3,
        preferredWeekdays: [2, 4, 6],
        busyDayPolicy: .skip
    )
    DynamicProgramTimelineView(program: program, anchorDate: Date(), builderViewModel: nil)
        .padding()
}
