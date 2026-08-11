//
//  ProgramPhaseGoalEditorSection.swift
//  FitLog
//
//  Edit surface for phase process goals in Review Program.
//

import SwiftUI

struct ProgramPhaseGoalEditorSection: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    @State private var titleDraft: String = ""
    @State private var summaryDraft: String = ""
    @State private var draftsBlockId: UUID?

    var body: some View {
        if let program = viewModel.generatedProgram,
           program.blocks.indices.contains(viewModel.editableBlockIndex) {
            let block = program.blocks[viewModel.editableBlockIndex]
            let goal = block.phaseGoal
            Section {
                if let goal {
                    TextField("Goal title", text: $titleDraft)
                        .accessibilityLabel("Phase goal title")
                        .onSubmit { commitCopy(blockIndex: viewModel.editableBlockIndex) }

                    TextField("Summary", text: $summaryDraft, axis: .vertical)
                        .lineLimit(2...4)
                        .accessibilityLabel("Phase goal summary")
                        .onSubmit { commitCopy(blockIndex: viewModel.editableBlockIndex) }

                    ForEach(goal.targets, id: \.kind) { target in
                        targetStepper(blockIndex: viewModel.editableBlockIndex, target: target)
                    }

                    if goal.targets.contains(where: { $0.source == .userSet }) || goal.copyIsUserSet {
                        Button("Reset to suggested") {
                            viewModel.resetPhaseGoalTargetsToSuggested(blockIndex: viewModel.editableBlockIndex)
                            syncDrafts(from: viewModel.generatedProgram?.blocks[safe: viewModel.editableBlockIndex]?.phaseGoal)
                        }
                        .accessibilityHint("Restores auto-calculated weekly targets for this phase")
                    }
                } else {
                    Text("Goals will appear after the program is generated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Phase goals")
            } footer: {
                Text("Weekly targets for this phase. Session and volume goals are tracked on Home after you save to Plan.")
            }
            .onAppear {
                syncDrafts(from: goal)
                draftsBlockId = block.id
            }
            .onChange(of: viewModel.editableBlockIndex) { oldIndex, newIndex in
                // Commit drafts to the block being left — not the newly selected one.
                commitDraftsForLeavingBlock(fallbackIndex: oldIndex)
                let next = viewModel.generatedProgram?.blocks[safe: newIndex]
                syncDrafts(from: next?.phaseGoal)
                draftsBlockId = next?.id
            }
            .onChange(of: block.id) { _, newId in
                guard draftsBlockId != newId else { return }
                syncDrafts(from: goal)
                draftsBlockId = newId
            }
            .onDisappear {
                commitDraftsForLeavingBlock(fallbackIndex: viewModel.editableBlockIndex)
            }
        }
    }

    @ViewBuilder
    private func targetStepper(blockIndex: Int, target: ProgramGoalTarget) -> some View {
        let step: Double = target.kind == .sessionsPerWeek ? 1 : (target.kind == .weeklyCardioMinutes ? 5 : 1)
        let range: ClosedRange<Double> = {
            switch target.kind {
            case .sessionsPerWeek: return 1...7
            case .weeklyHardSets: return 1...120
            case .weeklyCardioMinutes: return 0...300
            }
        }()

        Stepper(value: Binding(
            get: { target.value },
            set: { viewModel.updatePhaseGoalTarget(blockIndex: blockIndex, kind: target.kind, value: $0) }
        ), in: range, step: step) {
            HStack {
                Text(target.kind.shortLabel)
                Spacer()
                Text(target.displayValue)
                    .foregroundStyle(.secondary)
                if target.source == .userSet {
                    Text("Custom")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityLabel("\(target.kind.shortLabel) target, \(target.displayValue)")
        .accessibilityHint("Adjusts the weekly \(target.kind.unitLabel) goal")
    }

    private func syncDrafts(from goal: ProgramPhaseGoal?) {
        titleDraft = goal?.title ?? ""
        summaryDraft = goal?.summary ?? ""
    }

    /// Resolves the block that currently owns the text-field drafts, then commits if needed.
    private func commitDraftsForLeavingBlock(fallbackIndex: Int) {
        let index: Int? = {
            if let id = draftsBlockId,
               let found = viewModel.generatedProgram?.blocks.firstIndex(where: { $0.id == id }) {
                return found
            }
            guard viewModel.generatedProgram?.blocks.indices.contains(fallbackIndex) == true else { return nil }
            return fallbackIndex
        }()
        guard let index else { return }
        commitCopy(blockIndex: index)
    }

    private func commitCopy(blockIndex: Int) {
        guard let program = viewModel.generatedProgram,
              program.blocks.indices.contains(blockIndex),
              let current = program.blocks[blockIndex].phaseGoal else { return }
        let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summaryDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        if trimmedTitle == current.title, trimmedSummary == current.summary { return }
        viewModel.updatePhaseGoalCopy(blockIndex: blockIndex, title: trimmedTitle, summary: trimmedSummary)
    }
}

#Preview("Phase goal editor") {
    let vm = DynamicProgramBuilderViewModel()
    Form {
        ProgramPhaseGoalEditorSection(viewModel: vm)
    }
}
