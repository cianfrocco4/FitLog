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
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var userPreferences: UserPreferences
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
            .safeAreaInset(edge: .top, spacing: 0) {
                if let lastLoad = resolvedLastLoadCaption {
                    Text(lastLoad)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier(FitLogA11yID.splitBuilder.lastLoad)
                        .accessibilityLabel(lastLoad)
                        .accessibilityHint("Last working set or last cardio duration from a completed session")
                        .accessibilityAddTraits(.isStaticText)
                }
            }
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

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return OliveLastWorkingLoad.newestCompletedCaption(
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}
