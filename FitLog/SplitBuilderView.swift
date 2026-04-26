//
//  SplitBuilderView.swift
//  FitLog
//
//  Unified split-builder entry point: users choose AI assistance or manual control,
//  then both paths persist through the same flexible-workout split proposal model.
//

import SwiftUI

struct SplitBuilderView: View {
    @EnvironmentObject private var dataVM: DataManager
    @EnvironmentObject private var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.fitlogAISplitCoachPrefill) private var coachPrefill

    @State private var selectedPath: SplitBuilderPath?

    private enum SplitBuilderPath: Identifiable {
        case ai
        case manual

        var id: String {
            switch self {
            case .ai: return "ai"
            case .manual: return "manual"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose how you want to start. Both paths create editable training days, run balance checks, and can update your Plan calendar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Build a split") {
                    pathButton(
                        title: "AI builds it with me",
                        subtitle: "Answer a few questions, generate a complete split, then edit every day and slot before applying.",
                        systemImage: "sparkles",
                        path: .ai
                    )
                    pathButton(
                        title: "Build manually",
                        subtitle: "Start from blank, PPL, upper/lower, full-body, or muscle-group presets with the same analyzer.",
                        systemImage: "rectangle.stack.badge.plus",
                        path: .manual
                    )
                }
            }
            .navigationTitle("Build a split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedPath) { path in
                switch path {
                case .ai:
                    AISplitBuilderView()
                        .environmentObject(dataVM)
                        .environmentObject(currentVM)
                        .environmentObject(aiService)
                        .environment(\.fitlogRootTabSelection, rootTabSelection)
                        .environment(\.fitlogAISplitCoachPrefill, coachPrefill)
                        .toolbar(.hidden, for: .navigationBar)
                case .manual:
                    ManualSplitBuilderView()
                        .environmentObject(dataVM)
                        .environment(\.fitlogRootTabSelection, rootTabSelection)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
    }

    private func pathButton(title: String, subtitle: String, systemImage: String, path: SplitBuilderPath) -> some View {
        Button {
            selectedPath = path
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
