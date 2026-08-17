//
//  HistoryOverviewTab.swift
//  FitLog
//

import SwiftUI
import Charts

struct HistoryOverviewTab: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var userPreferences: UserPreferences
    @Bindable var viewModel: HistoryViewModel

    @State private var showVolumeInfo = false
    @State private var showPaywall = false
    @State private var paywallTrigger: PremiumFeature = .advancedAnalytics

    private var volumeUnit: String {
        HistoryFormatters.volumeUnitLabel(weightUnit: userPreferences.weightDisplayUnit)
    }

    private var kpiColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        Group {
            kpiSection
            if entitlementStore.hasAccess(to: .unlimitedHistory) {
                heatmapSection
            } else {
                premiumHistoryUpsell
            }
            if entitlementStore.hasAccess(to: .advancedAnalytics) {
                trendsSection
                muscleBalanceSection
            } else {
                premiumAnalyticsUpsell
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                triggerFeature: paywallTrigger,
                analyticsSource: paywallTrigger == .advancedAnalytics
                    ? "history_overview_analytics"
                    : "history_overview_history"
            )
            .environment(entitlementStore)
        }
        .popover(isPresented: $showVolumeInfo) {
            Text(HistoryFormatters.volumeUnitExplanation(weightUnit: userPreferences.weightDisplayUnit))
                .font(.subheadline)
                .padding()
                .presentationCompactAdaptation(.popover)
        }
    }

    private var kpiSection: some View {
        Section {
            if viewModel.sessionsInDateRange.isEmpty {
                emptyOverviewMessage
            } else {
                LazyVGrid(columns: kpiColumns, spacing: 10) {
                    HistoryKPITile(
                        title: "Sessions",
                        value: "\(viewModel.currentKPIs.sessions)",
                        deltaLine: viewModel.comparePriorPeriod
                            ? HistoryAggregator.deltaLine(
                                current: viewModel.currentKPIs.sessions,
                                prior: viewModel.priorKPIs.sessions,
                                invert: false
                            )
                            : nil,
                        systemImage: "figure.strengthtraining.traditional"
                    )
                    HistoryKPITile(
                        title: "Total sets",
                        value: HistoryFormatters.formatCompactInt(viewModel.currentKPIs.totalSets),
                        deltaLine: viewModel.comparePriorPeriod
                            ? HistoryAggregator.deltaLine(
                                current: viewModel.currentKPIs.totalSets,
                                prior: viewModel.priorKPIs.totalSets,
                                invert: false
                            )
                            : nil,
                        systemImage: "square.stack.3d.up.fill"
                    )
                    HistoryKPITile(
                        title: "Volume",
                        value: "\(HistoryFormatters.formatCompact(viewModel.currentKPIs.totalVolume)) \(volumeUnit)",
                        deltaLine: viewModel.comparePriorPeriod
                            ? HistoryAggregator.deltaLine(
                                current: Int(viewModel.currentKPIs.totalVolume.rounded()),
                                prior: Int(viewModel.priorKPIs.totalVolume.rounded()),
                                invert: false
                            )
                            : nil,
                        systemImage: "scalemass.fill",
                        showsInfoButton: true,
                        onInfo: { showVolumeInfo = true }
                    )
                    HistoryKPITile(
                        title: "Avg session",
                        value: HistoryFormatters.formatAvgDuration(viewModel.currentKPIs.avgSessionSeconds),
                        deltaLine: viewModel.comparePriorPeriod
                            ? HistoryAggregator.deltaLine(
                                current: viewModel.currentKPIs.avgSessionSeconds,
                                prior: viewModel.priorKPIs.avgSessionSeconds,
                                invert: true
                            )
                            : nil,
                        systemImage: "clock.fill"
                    )
                    HistoryKPITile(
                        title: "Days trained",
                        value: "\(viewModel.currentKPIs.daysTrained)",
                        deltaLine: viewModel.comparePriorPeriod
                            ? HistoryAggregator.deltaLine(
                                current: viewModel.currentKPIs.daysTrained,
                                prior: viewModel.priorKPIs.daysTrained,
                                invert: false
                            )
                            : nil,
                        systemImage: "calendar"
                    )
                    HistoryKPITile(
                        title: "Current streak",
                        value: viewModel.currentTrainingStreak == 0
                            ? "—"
                            : "\(viewModel.currentTrainingStreak) day\(viewModel.currentTrainingStreak == 1 ? "" : "s")",
                        deltaLine: nil,
                        systemImage: "flame.fill"
                    )
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("At a glance")
        } footer: {
            if !viewModel.sessionsInDateRange.isEmpty {
                Text("Showing data for \(viewModel.rangeDescription).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var emptyOverviewMessage: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nothing in this range yet")
                .font(.headline)
            Text("Finish a workout from Home or follow your Plan to populate History.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let tab = rootTabSelection {
                HStack(spacing: 12) {
                    Button("Home") { tab.wrappedValue = .home }
                        .buttonStyle(.borderedProminent)
                    Button("Plan") { tab.wrappedValue = .plan }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var heatmapSection: some View {
        Section {
            if dataVM.completedSessions.isEmpty {
                Text("Complete workouts to see your training density here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TrainingHeatmapView(days: viewModel.yearHeatmapDays)
                    .padding(.vertical, 4)
            }
        } header: {
            Text("Training year (365 days)")
        }
    }

    private var trendsSection: some View {
        Section {
            if viewModel.sessionsInDateRange.isEmpty {
                Text("Complete workouts to see trends")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    workoutsPerWeekChart
                    volumePerWeekChart
                    cardioChart
                    setsPerWeekChart
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text("Trends")
        }
    }

    private var workoutsPerWeekChart: some View {
        TrendChartCard(
            title: "Workouts per week",
            style: .bar(color: FitlogPalette.chartPrimary),
            weekStarts: viewModel.weeklyWorkouts.map(\.weekStart),
            values: viewModel.weeklyWorkouts.map { Double($0.count) },
            priorWeekStarts: viewModel.priorWeeklyWorkouts.map(\.weekStart),
            priorValues: viewModel.priorWeeklyWorkouts.map { Double($0.count) },
            showComparison: viewModel.comparePriorPeriod,
            average: weeklyWorkoutsAverage,
            averageLabel: averageWorkoutsLabel,
            yAxisFormatter: { "\(Int($0.rounded()))" },
            selectionAnnotation: { week, value in
                "Week of \(HistoryFormatters.formatMediumDate(week)): \(Int(value.rounded())) workouts"
            },
            accessibilitySummary: "Workouts per week trend chart",
            selectedWeek: $viewModel.selectedWorkoutsWeek
        )
    }

    private var volumePerWeekChart: some View {
        TrendChartCard(
            title: "Volume per week (\(volumeUnit))",
            style: .areaLine(
                areaGradient: [FitlogPalette.caution.opacity(0.35), FitlogPalette.caution.opacity(0.06)],
                lineColor: FitlogPalette.caution
            ),
            weekStarts: viewModel.weeklyVolume.map(\.weekStart),
            values: viewModel.weeklyVolume.map(\.volume),
            priorWeekStarts: viewModel.priorWeeklyVolume.map(\.weekStart),
            priorValues: viewModel.priorWeeklyVolume.map(\.volume),
            showComparison: viewModel.comparePriorPeriod,
            average: weeklyVolumeAverage,
            averageLabel: "avg \(HistoryFormatters.formatCompact(weeklyVolumeAverage ?? 0))",
            yAxisFormatter: HistoryFormatters.formatCompact,
            selectionAnnotation: { week, value in
                "Week of \(HistoryFormatters.formatMediumDate(week)): \(HistoryFormatters.formatCompact(value)) \(volumeUnit)"
            },
            accessibilitySummary: "Weekly training volume trend chart",
            selectedWeek: $viewModel.selectedVolumeWeek
        )
    }

    private var setsPerWeekChart: some View {
        TrendChartCard(
            title: "Sets per week",
            style: .areaLine(
                areaGradient: [FitlogPalette.success.opacity(0.32), FitlogPalette.success.opacity(0.06)],
                lineColor: FitlogPalette.success
            ),
            weekStarts: viewModel.weeklySetCounts.map(\.weekStart),
            values: viewModel.weeklySetCounts.map { Double($0.count) },
            priorWeekStarts: viewModel.priorWeeklySetCounts.map(\.weekStart),
            priorValues: viewModel.priorWeeklySetCounts.map { Double($0.count) },
            showComparison: viewModel.comparePriorPeriod,
            average: weeklySetsAverage,
            averageLabel: "avg \(HistoryFormatters.formatCompact(weeklySetsAverage ?? 0))",
            yAxisFormatter: { "\(Int($0.rounded()))" },
            selectionAnnotation: { week, value in
                "Week of \(HistoryFormatters.formatMediumDate(week)): \(Int(value.rounded())) sets"
            },
            accessibilitySummary: "Weekly sets trend chart",
            selectedWeek: $viewModel.selectedSetsWeek
        )
    }

    private var cardioChart: some View {
        CardioTrendChartCard(
            weeklyCardio: viewModel.weeklyCardio,
            priorWeeklyCardio: viewModel.priorWeeklyCardio,
            showComparison: viewModel.comparePriorPeriod,
            average: weeklyCardioAverage,
            selectedWeek: $viewModel.selectedCardioWeek
        )
    }

    @ViewBuilder
    private var muscleBalanceSection: some View {
        if !viewModel.sessionsInDateRange.isEmpty {
            Section {
                if viewModel.muscleVolumeRows.isEmpty {
                    Text("No muscle-tagged exercises in this range")
                        .foregroundStyle(.secondary)
                } else {
                    HistoryChartCard(title: "Volume by muscle (\(volumeUnit))", infoAction: { showVolumeInfo = true }) {
                        Chart(viewModel.muscleVolumeRows) { row in
                            BarMark(
                                x: .value("Volume", row.volume),
                                y: .value("Muscle", row.name)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.mint.opacity(0.85), .teal.opacity(0.75)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                        .chartXAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let n = v.as(Double.self) {
                                        Text(HistoryFormatters.formatCompact(n))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(preset: .aligned) { _ in
                                AxisValueLabel()
                            }
                        }
                        .frame(height: CGFloat(min(380, max(140, viewModel.muscleVolumeRows.count * 30))))
                        .accessibilityChartDescriptor(
                            MuscleVolumeChartAXDescriptor(
                                rows: viewModel.muscleVolumeRows,
                                valueFormatter: HistoryFormatters.formatCompact
                            )
                        )
                    }
                }
            } header: {
                Text("Muscle balance")
            }
        }
    }

    private var premiumHistoryUpsell: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Full training history", systemImage: "calendar")
                    .font(.headline)
                Text("Unlock the 365-day training heatmap and extended date ranges with Premium.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Unlock Premium") {
                    paywallTrigger = .unlimitedHistory
                    showPaywall = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(HistoryPremiumUpsellAccessibility.unlockLabel(for: .fullTrainingHistory))
                .accessibilityHint(HistoryPremiumUpsellAccessibility.unlockHint(for: .fullTrainingHistory))
            }
            .padding(.vertical, 4)
        }
    }

    private var premiumAnalyticsUpsell: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Label("Advanced analytics", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Text("Unlock muscle balance, recovery trends, volume charts, and extended history ranges with Premium.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Unlock Premium") {
                    paywallTrigger = .advancedAnalytics
                    showPaywall = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(HistoryPremiumUpsellAccessibility.unlockLabel(for: .advancedAnalytics))
                .accessibilityHint(HistoryPremiumUpsellAccessibility.unlockHint(for: .advancedAnalytics))
            }
            .padding(.vertical, 4)
        }
    }

    private var weeklyWorkoutsAverage: Double? {
        let values = viewModel.weeklyWorkouts.map { Double($0.count) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(viewModel.weeksInSelectedRange)
    }

    private var averageWorkoutsLabel: String {
        guard let avg = weeklyWorkoutsAverage else { return "" }
        return "avg \(Int(avg.rounded()))"
    }

    private var weeklyVolumeAverage: Double? {
        let values = viewModel.weeklyVolume.map(\.volume)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(viewModel.weeksInSelectedRange)
    }

    private var weeklySetsAverage: Double? {
        let values = viewModel.weeklySetCounts.map { Double($0.count) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(viewModel.weeksInSelectedRange)
    }

    private var weeklyCardioAverage: Double? {
        let values = viewModel.weeklyCardio.map(\.minutes)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(viewModel.weeksInSelectedRange)
    }
}
