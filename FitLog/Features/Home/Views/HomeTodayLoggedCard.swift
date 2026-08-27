//
//  HomeTodayLoggedCard.swift
//  FitLog
//
//  After finish, a Home recap so the log → History loop doesn’t require hunting the tab.
//

import SwiftUI

struct HomeTodayLoggedCard: View {
    let recap: HomeTodayLoggedSession.Recap
    let onViewInHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Logged today", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(FitlogPalette.success)

            Text(recap.workoutName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            if !recap.statsLine.isEmpty {
                Text(recap.statsLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: onViewInHistory) {
                Label("View in History", systemImage: "chart.bar.doc.horizontal")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(FitlogPalette.success)
            .accessibilityIdentifier(FitLogA11yID.homeViewInHistory)
            .accessibilityLabel("View in History")
            .accessibilityHint("Opens \(recap.workoutName) in History")
        }
        .homeCardTier(.secondary)
        .accessibilityElement(children: .contain)
    }

#Preview("Strength session") {
    HomeTodayLoggedCard(
        recap: HomeTodayLoggedSession.Recap(
            id: UUID(),
            workoutName: "Push A",
            durationSeconds: 42 * 60,
            workingSetCount: 18,
            cardioDurationSeconds: 0,
            libraryWorkoutId: UUID()
        ),
        onViewInHistory: {}
    )
    .padding()
}

#Preview("Dark cardio") {
    HomeTodayLoggedCard(
        recap: HomeTodayLoggedSession.Recap(
            id: UUID(),
            workoutName: "Zone 2",
            durationSeconds: 45 * 60,
            workingSetCount: 0,
            cardioDurationSeconds: 45 * 60,
            libraryWorkoutId: UUID()
        ),
        onViewInHistory: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
