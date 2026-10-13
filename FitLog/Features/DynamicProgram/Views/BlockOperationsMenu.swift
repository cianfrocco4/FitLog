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
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(FitLogA11yID.blockOperations.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    /// Current block first; otherwise newest completed session.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        let sessions = dataManager.completedSessions
        let unit = userPreferences.weightDisplayUnit
        if let program = viewModel.generatedProgram,
           program.blocks.indices.contains(viewModel.editableBlockIndex) {
            if let caption = IvyLastWorkingLoad.caption(
                forBlock: program.blocks[viewModel.editableBlockIndex],
                from: sessions,
                library: exerciseLibrary,
                displayUnit: unit
            ) {
                return caption
            }
        }
        return IvyLastWorkingLoad.newestCompletedCaption(from: sessions, displayUnit: unit)
    }
}
