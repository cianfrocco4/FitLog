//
//  HistorySessionRow.swift
//  FitLog
//

import SwiftUI

struct HistorySessionRow: View {
    let session: WorkoutSession
    let summary: HistorySessionSummary
    let volumeUnit: WeightDisplayUnit

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(session.workout.name)
                        .font(.headline)
                    if completedSessionIsSameCalendarDay(session) {
                        Text("Today")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(FitlogPalette.success)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(FitlogPalette.success.opacity(0.16), in: Capsule())
                            .accessibilityLabel("Logged today")
                    }
                }
                Text(HistoryFormatters.formatDateTime(session.endTime ?? session.startTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Opens this workout session")
    }

    private var rowAccessibilityLabel: String {
        var parts = [session.workout.name]
        if completedSessionIsSameCalendarDay(session) {
            parts.append("Logged today")
        }
        parts.append(HistoryFormatters.formatDateTime(session.endTime ?? session.startTime))
        parts.append("\(summary.setCount) sets")
        if summary.volume > 0 {
            parts.append(
                WeightStoreConversion.formatVolumeLbRep(summary.volume, unit: volumeUnit)
            )
        }
        if summary.durationSeconds > 0 {
            parts.append(HistoryFormatters.formatAvgDuration(summary.durationSeconds))
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Today — light") {
    HistorySessionRow(
        session: HistorySessionRowPreviewData.todayPush,
        summary: HistorySessionRowPreviewData.strengthSummary,
        volumeUnit: .pounds
    )
    .padding()
}

#Preview("Older session — dark") {
    HistorySessionRow(
        session: HistorySessionRowPreviewData.olderPull,
        summary: HistorySessionRowPreviewData.strengthSummary,
        volumeUnit: .pounds
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Today cardio — large type") {
    HistorySessionRow(
        session: HistorySessionRowPreviewData.todayCardio,
        summary: HistorySessionRowPreviewData.cardioSummary,
        volumeUnit: .pounds
    )
    .padding()
    .dynamicTypeSize(.accessibility2)
}

private enum HistorySessionRowPreviewData {
    static let todayPush: WorkoutSession = {
        let now = Date()
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Push A", exercises: []),
            startTime: now.addingTimeInterval(-3600),
            endTime: now,
            exerciseLogs: []
        )
    }()

    static let olderPull: WorkoutSession = {
        let end = Date().addingTimeInterval(-3 * 86400)
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Pull A", exercises: []),
            startTime: end.addingTimeInterval(-3600),
            endTime: end,
            exerciseLogs: []
        )
    }()

    static let todayCardio: WorkoutSession = {
        let now = Date()
        return WorkoutSession(
            id: UUID(),
            workout: Workout(id: UUID(), name: "Zone 2", exercises: [], workoutKind: .cardio),
            startTime: now.addingTimeInterval(-2700),
            endTime: now,
            exerciseLogs: []
        )
    }()

    static let strengthSummary = HistorySessionSummary(
        setCount: 12,
        volume: 8_400,
        durationSeconds: 3_600,
        prKinds: [.maxWeight]
    )

    static let cardioSummary = HistorySessionSummary(
        setCount: 1,
        volume: 0,
        durationSeconds: 2_700,
        prKinds: []
    )
}
