//
//  ReadinessDetailView.swift
//  FitLog
//

import SwiftUI

private enum ReadinessHealthAppLink {
    static let healthApp = URL(string: "x-apple-health://")!
}

struct ReadinessDetailView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @EnvironmentObject private var userPreferences: UserPreferences
    @Bindable var viewModel: ReadinessViewModel
    let dayKey: String

    @State private var showPaywall = false
    @State private var trendDays = 30

    var body: some View {
        List {
            switch viewModel.connectState {
            case .hidden:
                EmptyView()
            case .connect:
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                            .font(.headline)
                        Text("Allow read access to sleep, resting heart rate, and HRV for a fuller readiness score. Training load is always included.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button {
                            Task {
                                await viewModel.connectAppleHealth(
                                    dataVM: dataVM,
                                    dayKey: dayKey,
                                    userPreferences: userPreferences
                                )
                            }
                        } label: {
                            Label("Connect Apple Health", systemImage: "heart.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)
                        .accessibilityHint("Opens the Apple Health permission sheet")
                    }
                    .padding(.vertical, 4)
                }
            case .noData:
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("No recovery data yet", systemImage: "heart.slash")
                            .font(.headline)
                        Text("Apple Health is connected, but no recent sleep, HRV, or resting heart rate samples were found. Data from Apple Watch or other sources will appear here when available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link(destination: ReadinessHealthAppLink.healthApp) {
                            Label("Open Health app", systemImage: "arrow.up.forward.app")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Opens the Apple Health app")
                    }
                    .padding(.vertical, 4)
                }
            }

            if let score = viewModel.todayScore {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(score.score)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .accessibilityLabel("Readiness score \(score.score) out of 100")
                        Text(score.band.displayTitle)
                            .font(.title3.weight(.semibold))
                        Text(score.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("How it's calculated") {
                    ForEach(score.components) { component in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(component.kind.displayTitle, systemImage: component.kind.systemImage)
                                .font(.headline)
                            Text(component.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if component.isAvailable {
                                Text("Component score: \(Int(component.score.rounded()))/100")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    Text("Readiness combines HRV vs your baseline, resting heart rate, sleep duration, and recent training load. It is not medical advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Trends") {
                    if entitlementStore.hasAccess(to: .readinessTrends) {
                        Picker("Range", selection: $trendDays) {
                            Text("7 days").tag(7)
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                        }
                        .pickerStyle(.segmented)
                        ReadinessTrendChartView(scores: viewModel.trendScores)
                            .listRowInsets(EdgeInsets())
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("See how readiness changes over time with Premium.")
                                .font(.subheadline)
                            Button("Unlock readiness trends") { showPaywall = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } else if viewModel.isLoading {
                Section {
                    ProgressView("Loading readiness…")
                }
            } else {
                Section {
                    Text(viewModel.errorMessage ?? "Readiness data is unavailable.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh(dataVM: dataVM, dayKey: dayKey, userPreferences: userPreferences)
            viewModel.loadTrend(dataVM: dataVM, days: trendDays, endingDayKey: dayKey)
        }
        .onChange(of: trendDays) { _, newValue in
            viewModel.loadTrend(dataVM: dataVM, days: newValue, endingDayKey: dayKey)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: .readinessTrends)
                .environment(entitlementStore)
        }
    }
}

#Preview {
    ReadinessTrendChartView(scores: [])
}
