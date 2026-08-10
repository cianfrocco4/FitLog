//
//  SplitBuilderView.swift
//  FitLog
//
//  Presents the program builder entry (Guided Coach, Templates, or Advanced Builder).
//

import SwiftUI

struct SplitBuilderView: View {
    /// When set, opens the wizard on the review step with this program loaded (edit / re-apply).
    var hydrateFromState: DynamicProgramState? = nil

    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.fitlogAISplitCoachPrefill) private var coachPrefill

    @State private var viewModel = DynamicProgramBuilderViewModel()
    @State private var didMergeCoachPrefill = false
    @State private var didHydrateFromSavedState = false
    @State private var confirmDiscardUnsavedProgram = false

    var body: some View {
        NavigationStack {
            Group {
                if hydrateFromState != nil {
                    DynamicProgramBuilderView(viewModel: viewModel)
                } else {
                    ProgramBuilderEntryView(viewModel: viewModel)
                }
            }
            .environment(dataVM)
            .environment(currentVM)
            .environmentObject(aiService)
            .environment(\.fitlogRootTabSelection, rootTabSelection)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if viewModel.hasUnsavedProgramChanges {
                            confirmDiscardUnsavedProgram = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityHint(
                        viewModel.hasUnsavedProgramChanges
                            ? "Asks before discarding unsaved program changes"
                            : "Closes the program builder"
                    )
                }
            }
            .interactiveDismissDisabled(viewModel.hasUnsavedProgramChanges)
            .confirmationDialog(
                "Discard unsaved changes?",
                isPresented: $confirmDiscardUnsavedProgram,
                titleVisibility: .visible
            ) {
                Button("Discard changes", role: .destructive) {
                    dismiss()
                }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("This program has changes that are not in your Plan. Closing now discards them.")
            }
            .onAppear {
                if !didHydrateFromSavedState, let snapshot = hydrateFromState {
                    didHydrateFromSavedState = true
                    viewModel.hydrate(from: snapshot)
                }
                guard !didMergeCoachPrefill else { return }
                if let prefill = coachPrefill?.trimmingCharacters(in: .whitespacesAndNewlines), !prefill.isEmpty {
                    didMergeCoachPrefill = true
                    let existing = viewModel.request.splitInput.additionalNotes
                    viewModel.request.splitInput.additionalNotes = existing.isEmpty ? prefill : "\(existing)\n\(prefill)"
                }
            }
        }
    }
}
