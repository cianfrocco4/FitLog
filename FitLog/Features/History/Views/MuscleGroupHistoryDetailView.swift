//
//  MuscleGroupHistoryDetailView.swift
//  FitLog
//

import SwiftUI
import Charts

struct MuscleGroupHistoryDetailView: View {
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var userPreferences: UserPreferences
    let muscleGroupName: String
    let sessions: [WorkoutSession]

    private var sessionLogs: [(session: WorkoutSession, logs: [ExerciseLog])] {
        sessions.compactMap { session in
            let logs = session.exerciseLogs.filter { log in
                guard let snap = log.workoutExercise.snapshot,
                      let ex = dataVM.resolveExercise(for: snap) else { return false }
                return ex.targetedMuscles.contains(where: { $0.rawValue == muscleGroupName })
                    || (ex.targetedMuscles.isEmpty && muscleGroupName == MuscleGroup.other.rawValue)
            }
            if logs.isEmpty { return nil }
            return (session, logs)
        }.sorted { ($0.session.endTime ?? $0.session.startTime) > ($1.session.endTime ?? $1.session.startTime) }
    }

    private var muscleVolumeTrendPoints: [MuscleSessionVolumePoint] {
        sessionLogs
            .sorted { ($0.session.endTime ?? $0.session.startTime) < ($1.session.endTime ?? $1.session.startTime) }
            .map { item in
                let vol = item.logs.reduce(0.0) { acc, log in
                    acc + log.loggedSets.reduce(0) { $0 + $1.totalVolumeLoad }
                }
                let d = item.session.endTime ?? item.session.startTime
                return MuscleSessionVolumePoint(id: item.session.id, date: d, volume: vol)
            }
    }

    private var volumeUnit: String {
        HistoryFormatters.volumeUnitLabel(weightUnit: userPreferences.weightDisplayUnit)
    }

    var body: some View {
        List {
            if muscleVolumeTrendPoints.count >= 2 {
                Section {
                    HistoryChartCard(title: "Volume per session (\(volumeUnit))") {
                        Chart(muscleVolumeTrendPoints) { pt in
                            BarMark(
                                x: .value("Date", pt.date),
                                y: .value("Volume", pt.volume)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.teal, .mint.opacity(0.85)], startPoint: .bottom, endPoint: .top)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, muscleVolumeTrendPoints.count / 4))) { _ in
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
                        .accessibilityLabel("Muscle group volume per session")
                    }
                } header: {
                    Text("Trend")
                }
            }
            ForEach(sessionLogs, id: \.session.id) { item in
                Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Workout")
                        Spacer()
                        Text(item.session.workout.name)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(item.logs) { log in
                        DisclosureGroup {
                            ForEach(log.loggedSets) { set in
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
                                    let summary = set.configurationSummary(fieldNames: log.workoutExercise.configurationFields)
                                    if !summary.isEmpty {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dataVM.displayName(for: log.workoutExercise))
                                if let slotLabel = HistoryView.templateSlotCaption(for: log, session: item.session, dataVM: dataVM) {
                                    Text("From plan: \(slotLabel)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(HistoryView.formatDateStatic(item.session.endTime ?? item.session.startTime))
                }
            }
        }
        .navigationTitle(muscleGroupName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
