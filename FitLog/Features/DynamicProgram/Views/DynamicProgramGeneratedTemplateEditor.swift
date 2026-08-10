//
//  DynamicProgramGeneratedTemplateEditor.swift
//  FitLog
//
//  Post-generation editing for weekly templates (per block) before applying a dynamic program.
//

import SwiftUI

struct DynamicProgramGeneratedTemplateEditor: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    /// When true, shows summary cards only; editing happens via the focused editor surface.
    var overviewOnly: Bool = false
    let onRequestEdit: (Int, Int?) -> Void
    let onBalanceAction: (SplitProposalProgramWarning) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expandedBlockIds: Set<UUID> = []

    var body: some View {
        Group {
            if let prog = viewModel.generatedProgram, !prog.blocks.isEmpty {
                Section {
                    ForEach(Array(prog.blocks.enumerated()), id: \.element.id) { index, block in
                        blockReviewSection(blockIndex: index, block: block)
                    }
                } header: {
                    Text("Program blocks")
                } footer: {
                    Text(overviewOnly
                        ? "Show workouts to review days. Tap a day to edit exercises without leaving Overview. Balance suggestions can apply a fix, open a day, or regenerate."
                        : "Expand a block to review days, then edit templates below. Changes are included when you save to Plan.")
                        .font(.caption)
                }

                if !overviewOnly, prog.blocks.indices.contains(viewModel.editableBlockIndex) {
                    Section {
                        DynamicProgramBlockTemplateEditorSection(
                            days: viewModel.bindingForBlockDays(viewModel.editableBlockIndex),
                            enableManualSlotChrome: true,
                            preferredDayIndex: viewModel.editableDayIndex,
                            onStructuralChange: {
                                viewModel.commitStructuralEdit()
                            },
                            onSlotFieldChange: {
                                viewModel.commitFieldEdit()
                            },
                            onBeforeStructuralChange: {
                                viewModel.pushUndoSnapshot()
                            },
                            onSlotRemoved: { name in
                                viewModel.undoBannerMessage = "Removed “\(name)” — Undo"
                            }
                        )
                    } header: {
                        Text("Edit — \(prog.blocks[viewModel.editableBlockIndex].name)")
                    }
                }
            }
        }
        .onAppear {
            seedExpandedBlocksIfNeeded()
        }
        .onChange(of: viewModel.generatedProgram?.id) { _, _ in
            seedExpandedBlocksIfNeeded()
        }
    }

    @ViewBuilder
    private func blockReviewSection(blockIndex: Int, block: ProgramBlock) -> some View {
        let warnings = viewModel.balanceWarningsForBlock(at: blockIndex)
        let stats = ProgramBlockSummarySupport.stats(
            forBlockIndex: blockIndex,
            editableDays: viewModel.perBlockEditableDays,
            program: viewModel.generatedProgram ?? DynamicProgram(name: "", blocks: [], defaultSessionsPerWeek: 1),
            warnings: warnings
        )
        let isExpanded = expandedBlockIds.contains(block.id)

        VStack(alignment: .leading, spacing: 10) {
            ProgramBlockSummaryCard(
                block: block,
                blockIndex: blockIndex,
                stats: stats,
                warnings: warnings,
                isSelected: viewModel.editableBlockIndex == blockIndex,
                isExpanded: isExpanded,
                onSelect: {
                    viewModel.selectEditableBlock(blockIndex)
                    if overviewOnly {
                        onRequestEdit(blockIndex, nil)
                    }
                },
                onToggleExpanded: {
                    if reduceMotion {
                        toggleExpanded(block.id)
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            toggleExpanded(block.id)
                        }
                    }
                }
            )

            if isExpanded {
                Text("Workouts in this block")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)

                blockDaySummaryRows(blockIndex: blockIndex)

                if !warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Balance")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(warnings) { warning in
                            BalanceSuggestionRow(
                                warning: warning,
                                onAction: {
                                    viewModel.selectEditableBlock(blockIndex)
                                    onBalanceAction(warning)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func blockDaySummaryRows(blockIndex: Int) -> some View {
        if viewModel.perBlockEditableDays.indices.contains(blockIndex) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(viewModel.perBlockEditableDays[blockIndex].enumerated()), id: \.element.id) { dayIndex, day in
                    Button {
                        viewModel.selectEditableBlock(blockIndex)
                        viewModel.selectEditableDay(dayIndex)
                        onRequestEdit(blockIndex, dayIndex)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(day.name.isEmpty ? "Untitled day" : day.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Text("\(day.slots.count) slots")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            if !day.focus.isEmpty {
                                Text(day.focus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(dayExercisePreview(day))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.tertiarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.name.isEmpty ? "Untitled day" : day.name), \(day.slots.count) slots")
                    .accessibilityHint("Opens the day editor")
                }
            }
        }
    }

    private func dayExercisePreview(_ day: SplitBuilderEditableDay) -> String {
        let names = day.slots.map { slot -> String in
            if let n = slot.suggestedExerciseName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                return n
            }
            let label = slot.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? "Slot" : label
        }
        return names.isEmpty ? "No exercises yet" : names.joined(separator: ", ")
    }

    private func toggleExpanded(_ blockId: UUID) {
        if expandedBlockIds.contains(blockId) {
            expandedBlockIds.remove(blockId)
        } else {
            expandedBlockIds.insert(blockId)
        }
    }

    private func seedExpandedBlocksIfNeeded() {
        guard expandedBlockIds.isEmpty,
              let prog = viewModel.generatedProgram else { return }
        if prog.blocks.count == 1, let first = prog.blocks.first?.id {
            expandedBlockIds = [first]
        }
    }
}

/// Actionable balance suggestion row for program review.
struct BalanceSuggestionRow: View {
    let warning: SplitProposalProgramWarning
    let onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: warning.severity == .caution ? "exclamationmark.triangle.fill" : "info.circle")
                    .font(.caption)
                    .foregroundStyle(warning.severity == .caution ? Color.orange : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(warning.message)
                        .font(.caption2)
                        .foregroundStyle(warning.severity == .caution ? Color.orange : Color.secondary)
                        .multilineTextAlignment(.leading)
                    if let title = actionTitle {
                        Text(title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(warning.suggestion == nil)
        .accessibilityLabel(warning.message)
        .accessibilityHint(actionTitle.map { "\($0)" } ?? "Informational suggestion")
    }

    private var actionTitle: String? {
        ProgramReviewSuggestion.actionTitle(for: warning.suggestion)
    }
}
