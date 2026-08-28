//
//  HistoryTodayLoggedCard.swift
//  FitLog
//
//  Compact Overview row confirming today’s workout is already in History.
//

import SwiftUI

struct HistoryTodayLoggedCard: View {
    let recap: HistoryTodayLoggedRecap.Recap

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(FitlogPalette.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Logged today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.success)
                Text(recap.workoutName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !recap.statsLine.isEmpty {
                    Text(recap.statsLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this session in History")
        .accessibilityIdentifier(FitLogA11yID.historyTodayLogged)
    }

    private var accessibilityLabel: String {
        var parts = ["Logged today", recap.workoutName]
        if !recap.statsLine.isEmpty {
            parts.append(recap.statsLine)
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Strength") {
    HistoryTodayLoggedCard(
        recap: HistoryTodayLoggedRecap.Recap(
            id: UUID(),
            workoutName: "Push A",
            durationSeconds: 42 * 60,
            workingSetCount: 18,
            cardioDurationSeconds: 0
        )
    )
    .padding()
}

#Preview("Cardio") {
    HistoryTodayLoggedCard(
        recap: HistoryTodayLoggedRecap.Recap(
            id: UUID(),
            workoutName: "Zone 2",
            durationSeconds: 45 * 60,
            workingSetCount: 0,
            cardioDurationSeconds: 45 * 60
        )
    )
    .padding()
    .preferredColorScheme(.dark)
}
