//
//  BlockOperationsMenu.swift
//  FitLog
//
//  Duplicate / copy / import operations for program blocks in manual mode.
//

import SwiftUI

struct BlockOperationsMenu: View {
    @Bindable var viewModel: DynamicProgramBuilderViewModel
    let exerciseLibrary: [Exercise]
    @Binding var showImportRotationSheet: Bool

    var body: some View {
        Menu {
            Button {
                viewModel.duplicateProgramBlock(at: viewModel.editableBlockIndex)
            } label: {
                Label("Duplicate this block", systemImage: "plus.square.on.square")
            }
            .disabled(viewModel.generatedProgram == nil)
            .accessibilityHint("Inserts a copy of the current block after it with fresh template ids.")

            Button {
                viewModel.copyWeeklyTemplatesFromPreviousBlock(into: viewModel.editableBlockIndex)
            } label: {
                Label("Copy rotation from previous block", systemImage: "doc.on.doc")
            }
            .disabled(viewModel.editableBlockIndex == 0 || viewModel.generatedProgram == nil)
            .accessibilityHint("Replaces this block’s templates with a deep copy of the prior block.")

            Button {
                showImportRotationSheet = true
            } label: {
                Label("Import rotation from workout…", systemImage: "square.and.arrow.down")
            }
            .disabled(viewModel.generatedProgram == nil)
            .accessibilityHint("Replaces this block’s rotation with a single day built from a library workout.")
        } label: {
            Label("Block actions", systemImage: "ellipsis.circle")
        }
        .accessibilityLabel("Block actions menu")
    }
}
