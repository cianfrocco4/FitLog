//
//  WeeklyInsightCard.swift
//  FitLog
//

import SwiftUI

struct WeeklyInsightCard: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var aiService: AIService
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var viewModel = InsightsViewModel()
    var readinessTrendSummaries: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Week in review", systemImage: "text.book.closed")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button("Refresh") {
                        Task {
                            await viewModel.regenerate(
                                dataVM: dataVM,
                                aiService: aiService,
                                entitlementStore: entitlementStore,
                                readinessTrendSummaries: readinessTrendSummaries
                            )
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityHint("Regenerates this week's insight")
                }
            }

            if let insight = viewModel.insight {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.narrative)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !insight.highlights.isEmpty {
                    bulletBlock(title: "Highlights", items: insight.highlights, systemImage: "checkmark.circle")
                }
                if !insight.risks.isEmpty {
                    bulletBlock(title: "Watch", items: insight.risks, systemImage: "exclamationmark.triangle")
                }
                if !insight.nextActions.isEmpty {
                    bulletBlock(title: "Next", items: insight.nextActions, systemImage: "arrow.right.circle")
                }

                Text("Not medical advice · \(insight.routeUsed.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if !entitlementStore.isPremium {
                Text("Premium unlocks a natural-language summary of your training week.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("See Premium") { viewModel.showPaywall = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("Generate a private summary of this week's training.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Generate insight") {
                    Task {
                        await viewModel.loadCachedOrGenerate(
                            dataVM: dataVM,
                            aiService: aiService,
                            entitlementStore: entitlementStore,
                            readinessTrendSummaries: readinessTrendSummaries
                        )
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task {
            if entitlementStore.isPremium {
                await viewModel.loadCachedOrGenerate(
                    dataVM: dataVM,
                    aiService: aiService,
                    entitlementStore: entitlementStore,
                    readinessTrendSummaries: readinessTrendSummaries
                )
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView(triggerFeature: .aiCoach, analyticsSource: "weekly_insight")
                .environment(entitlementStore)
        }
        .accessibilityElement(children: .contain)
    }

    private func bulletBlock(title: String, items: [String], systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: systemImage)
                    .font(.caption)
            }
        }
    }
}
