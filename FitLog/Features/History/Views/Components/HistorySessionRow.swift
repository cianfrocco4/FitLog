//
//  HistorySessionRow.swift
//  FitLog
//

import SwiftUI

struct HistorySessionRow: View {
    let session: WorkoutSession
    let summary: HistorySessionSummary
    let volumeUnit: WeightDisplayUnit

    private var lastWorkingLabel: String? {
        guard let snap = HomeLastWorkingLoad.snapshot(from: session) else { return nil }
        return HomeWorkoutFormatting.compactWeightLabel(pounds: snap.weightPounds, unit: volumeUnit)
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.workout.name)
                    .font(.headline)
                Text(HistoryFormatters.formatDateTime(session.endTime ?? session.startTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let lastWorkingLabel {
                    Text("Last set \(lastWorkingLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Last working set \(lastWorkingLabel)")
                }
                HStack(spacing: 12) {
                    Label("\(summary.setCount) sets", systemImage: "square.stack.3d.up")
                    if summary.volume > 0 {
                        Label(
                            WeightStoreConversion.formatVolumeLbRep(summary.volume, unit: volumeUnit),
                            systemImage: "scalemass"
                        )
                    }
                    Label(HistoryFormatters.formatAvgDuration(summary.durationSeconds), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !summary.prKinds.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(summary.prKinds, id: \.self) { kind in
                            Text(historySessionPRBadgeLabel(kind))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(FitlogPalette.highlight)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(FitlogPalette.highlight.opacity(0.15), in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
    }
}
