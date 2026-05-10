//
//  DynamicProgramGeneratedTemplateEditor.swift
//  FitLog
//
//  Post-generation editing for weekly templates (per block) before applying a dynamic program.
//

import SwiftUI

struct DynamicProgramGeneratedTemplateEditor: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel

    var body: some View {
        Group {
            if let prog = viewModel.generatedProgram, !prog.blocks.isEmpty {
                Section {
                    if prog.blocks.count > 1 {
                        Picker("Edit block", selection: Binding(
                            get: { viewModel.editableBlockIndex },
                            set: { viewModel.selectEditableBlock($0) }
                        )) {
                            ForEach(Array(prog.blocks.enumerated()), id: \.element.id) { idx, block in
                                Text(block.name).tag(idx)
                            }
                        }
                        .accessibilityLabel("Block to edit")
                    }
                } header: {
                    Text("Templates")
                } footer: {
                    Text("Changes are included when you review and save to Plan.")
                        .font(.caption)
                }

                Section {
                    DynamicProgramBlockTemplateEditorSection(
                        days: viewModel.bindingForBlockDays(viewModel.editableBlockIndex),
                        onStructuralChange: {
                            viewModel.refreshGenerationBalanceWarnings()
                        },
                        onSlotFieldChange: {
                            viewModel.refreshGenerationBalanceWarnings()
                        }
                    )
                } header: {
                    Text("Training days")
                }
            }
        }
    }
}
