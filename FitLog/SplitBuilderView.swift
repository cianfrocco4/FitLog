//
//  SplitBuilderView.swift
//  FitLog
//
//  Presents the dynamic program wizard (single entry point for building programs).
//

import SwiftUI

struct SplitBuilderView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.fitlogAISplitCoachPrefill) private var coachPrefill

    @State private var viewModel = DynamicProgramBuilderViewModel()
    @State private var didMergeCoachPrefill = false

    var body: some View {
        NavigationStack {
            DynamicProgramBuilderView(viewModel: viewModel)
                .environment(dataVM)
                .environment(currentVM)
                .environmentObject(aiService)
                .environment(\.fitlogRootTabSelection, rootTabSelection)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .accessibilityHint("Closes the program builder")
                    }
                }
                .onAppear {
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
