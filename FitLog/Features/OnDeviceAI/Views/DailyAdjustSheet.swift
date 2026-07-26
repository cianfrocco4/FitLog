//
//  DailyAdjustSheet.swift
//  FitLog
//

import SwiftUI

struct DailyAdjustSheet: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var aiService: AIService
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss

    let readinessScore: ReadinessScore?
    let plannedWorkout: Workout?

    @State private var viewModel = DailyAdjustViewModel()

    var body: some View {
        NavigationStack {
            Form {
                if let note = viewModel.availabilityNote {
                    Section {
                        Label(note, systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(note)
                    }
                }

                Section("How are you feeling?") {
                    TextField("Optional note (e.g. shoulders sore, slept poorly)", text: $viewModel.userNote, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("How you feel today")
                        .accessibilityHint("Optional note used to adjust today's plan")
                }

                Section {
                    Button {
                        Task {
                            await viewModel.generate(
                                dataVM: dataVM,
                                aiService: aiService,
                                entitlementStore: entitlementStore,
                                readinessScore: readinessScore,
                                plannedWorkout: plannedWorkout
                            )
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("Suggest adjustment", systemImage: "sparkles")
                        }
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityHint("Generates a readiness-aware plan adjustment")
                }

                if let proposal = viewModel.proposal {
                    Section("Recommendation") {
                        Text(proposal.summary)
                            .font(.headline)
                        Text(proposal.rationale)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(proposal.changes) { change in
                            Label(change.detail, systemImage: "arrow.triangle.branch")
                                .font(.subheadline)
                        }
                        Text("Route: \(proposal.routeUsed.rawValue) · Not medical advice")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Section {
                        Button("Accept changes") {
                            viewModel.accept(dataVM: dataVM)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Applies the suggested changes to today's plan")

                        Button("Dismiss") { dismiss() }
                    }
                }

                if let message = viewModel.applyResultMessage {
                    Section {
                        Text(message)
                            .font(.subheadline)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Adjust today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView(triggerFeature: .aiCoach, analyticsSource: "daily_adjust")
                    .environment(entitlementStore)
            }
        }
    }
}
