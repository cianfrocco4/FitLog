//
//  ExerciseHistoryDetailView.swift
//  FitLog
//

import SwiftUI
import Charts

struct ExerciseHistoryDetailView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(EntitlementStore.self) private var entitlementStore
    @EnvironmentObject var userPreferences: UserPreferences
    let exerciseId: UUID
    let rangeSessions: [WorkoutSession]
    let allSessionsSorted: [WorkoutSession]
    @State private var dataScope: ExerciseHistoryDataScope = .selectedRange
    @State private var showPaywall = false
    /// Bumps when a Premium-only scope is rejected so the segmented picker resyncs visually.
    @State private var dataScopePickerEpoch = 0

    /// Rejects All-time for free users without briefly mutating `dataScope` (avoids chart/session flash).
    private var dataScopeSelection: Binding<ExerciseHistoryDataScope> {
        PremiumGatedSelection.binding(
            get: { dataScope },
            set: { dataScope = $0 },
            requiresPremium: { $0.requiresPremium },
            hasPremiumAccess: { entitlementStore.hasAccess(to: .unlimitedHistory) },
            onDenied: { showPaywall = true },
            resyncToken: $dataScopePickerEpoch
        )
    }

    private var effectiveSessions: [WorkoutSession] {
        switch dataScope {
        case .selectedRange:
            return rangeSessions
        case .allTime:
            return allSessionsSorted
        }
    }

    private var sessionLogs: [(session: WorkoutSession, log: ExerciseLog)] {
        effectiveSessions.compactMap { session in
            guard let log = session.exerciseLogs.first(where: {
                $0.workoutExercise.exerciseId == exerciseId
                    || $0.workoutExercise.snapshot?.exerciseId == exerciseId
            }) else { return nil }
            return (session, log)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    private var navigationTitle: String {
        if let ex = dataVM.globalExercises.first(where: { $0.id == exerciseId }) {
            return dataVM.resolvedDisplayName(for: ex)
        }
        if let log = sessionLogs.first?.log {
            return dataVM.displayName(for: log.workoutExercise)
        }
        return "Exercise"
    }

    private var progressionSeries: [ExerciseProgressionPoint] {
        sessionLogs.compactMap { item -> ExerciseProgressionPoint? in
            guard let est = HistoryAggregator.bestWorkingEst1RM(for: item.log) else { return nil }
            let date = item.session.endTime ?? item.session.startTime
            return ExerciseProgressionPoint(id: item.session.id, date: date, estOneRM: est)
        }
        .sorted { $0.date < $1.date }
    }

    private var progressionLoadAxisLabel: String { userPreferences.weightDisplayUnit.shortLabel }

    private func progressionChartY(_ estStoredLb: Double) -> Double {
        WeightStoreConversion.displayValue(storedPounds: estStoredLb, unit: userPreferences.weightDisplayUnit)
    }

    private var progressionInsight: String? {
        guard let peak = progressionSeries.map(\.estOneRM).max(), peak > 0 else { return nil }
        let d = WeightStoreConversion.displayValue(storedPounds: peak, unit: userPreferences.weightDisplayUnit)
        let rounded = d == floor(d) ? "\(Int(d))" : String(format: "%.1f", d)
        let u = userPreferences.weightDisplayUnit.shortLabel
        return "Peak estimated 1RM in this range: \(rounded) \(u) (Epley, working sets only)."
    }

    private var volumeSeries: [ExerciseVolumePoint] {
        sessionLogs.map { item in
            let vol = item.log.loggedSets.reduce(0.0) { $0 + $1.totalVolumeLoad }
            let d = item.session.endTime ?? item.session.startTime
            return ExerciseVolumePoint(id: item.session.id, date: d, volumeLbRep: vol)
        }
        .sorted { $0.date < $1.date }
    }

    private var volumeAxisLabel: String {
        HistoryFormatters.volumeUnitLabel(weightUnit: userPreferences.weightDisplayUnit)
    }

    private func volumeChartY(_ lbRep: Double) -> Double {
        WeightStoreConversion.volumeDisplayValue(lbRep: lbRep, unit: userPreferences.weightDisplayUnit)
    }

    var body: some View {
        List {
            Section {
                Picker("Scope", selection: dataScopeSelection) {
                    ForEach(ExerciseHistoryDataScope.allCases, id: \.rawValue) { scope in
                        if scope.requiresPremium, !entitlementStore.hasAccess(to: .unlimitedHistory) {
                            Label("\(scope.label) (Premium)", systemImage: "lock.fill").tag(scope)
                        } else {
                            Text(scope.label).tag(scope)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .id(dataScopePickerEpoch)
            } footer: {
                Text(
                    dataScope == .selectedRange
                        ? "Matches the time range on the History tab."
                        : "Every session that included this exercise (no date limit)."
                )
                .font(.caption2)
            }

            if !progressionSeries.isEmpty {
                Section {
                    if progressionSeries.count >= 2 {
                        HistoryChartCard(title: "Strength trend (est. 1RM)") {
                            Chart(progressionSeries) { pt in
                                AreaMark(
                                    x: .value("Session", pt.date),
                                    y: .value(progressionLoadAxisLabel, progressionChartY(pt.estOneRM))
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [FitlogPalette.chartSecondary.opacity(0.28), FitlogPalette.chartSecondary.opacity(0.06)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                                LineMark(
                                    x: .value("Session", pt.date),
                                    y: .value(progressionLoadAxisLabel, progressionChartY(pt.estOneRM))
                                )
                                .foregroundStyle(FitlogPalette.chartSecondary)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                                .interpolationMethod(.catmullRom)
                                PointMark(
                                    x: .value("Session", pt.date),
                                    y: .value(progressionLoadAxisLabel, progressionChartY(pt.estOneRM))
                                )
                                .foregroundStyle(FitlogPalette.chartSecondary)
                                .symbolSize(36)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: max(1, progressionSeries.count / 3))) { _ in
                                    AxisGridLine()
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                            .chartYAxis {
                                AxisMarks { v in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let n = v.as(Double.self) {
                                            Text(HistoryFormatters.formatCompact(n))
                                        }
                                    }
                                }
                            }
                            .frame(height: 200)
                            .accessibilityLabel("Strength progression chart")
                        }
                    }
                    if let progressionInsight {
                        Text(progressionInsight)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Progression")
                }
            }

            if volumeSeries.count >= 2 {
                Section {
                    HistoryChartCard(title: "Volume per session") {
                        Chart(volumeSeries) { pt in
                            BarMark(
                                x: .value("Session", pt.date),
                                y: .value(volumeAxisLabel, volumeChartY(pt.volumeLbRep))
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.mint, .teal.opacity(0.85)], startPoint: .bottom, endPoint: .top)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, volumeSeries.count / 3))) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .chartYAxis {
                            AxisMarks { v in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let n = v.as(Double.self) {
                                        Text(HistoryFormatters.formatCompact(n))
                                    }
                                }
                            }
                        }
                        .frame(height: 188)
                        .accessibilityLabel("Volume per session chart")
                    }
                } header: {
                    Text("Volume trend")
                } footer: {
                    Text("Sum of load × reps for this exercise each session (including drop segments).")
                        .font(.caption2)
                }
            }

            ForEach(sessionLogs, id: \.session.id) { item in
                Section {
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(item.session.workout.name)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                            .foregroundStyle(.secondary)
                    }
                    if let slotLabel = HistoryView.templateSlotCaption(for: item.log, session: item.session, dataVM: dataVM) {
                        HStack {
                            Text("Template slot")
                            Spacer()
                            Text(slotLabel)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    ForEach(item.log.loggedSets) { set in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(set.weightRepsDisplaySummary(displayUnit: userPreferences.weightDisplayUnit))
                                if let badge = set.setTypeBadgeLabel {
                                    Text(badge)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                Spacer()
                            }
                            let summary = set.configurationSummary(fieldNames: item.log.workoutExercise.configurationFields)
                            if !summary.isEmpty {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: .unlimitedHistory)
                .environment(entitlementStore)
        }
    }
}
