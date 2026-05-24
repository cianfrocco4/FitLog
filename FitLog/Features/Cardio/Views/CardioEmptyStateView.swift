//
//  CardioEmptyStateView.swift
//  FitLog
//

import SwiftUI

/// Reusable empty state when no cardio has been logged or no cardio workouts exist yet.
struct CardioEmptyStateView: View {
    var title: String = "No cardio logged yet"
    var message: String = "Build a cardio workout with steady-state or interval templates, then log time and distance during your session."
    var primaryTitle: String = "Build cardio workout"
    var primaryAccessibilityHint: String = "Opens the cardio workout builder"
    var onPrimary: () -> Void
    var secondaryTitle: String? = "Browse cardio library"
    var onSecondary: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundStyle(FitlogPalette.chartSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: onPrimary) {
                Label(primaryTitle, systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(FitlogPalette.chartSecondary)
            .accessibilityHint(primaryAccessibilityHint)
            if let secondaryTitle, let onSecondary {
                Button(secondaryTitle, action: onSecondary)
                    .buttonStyle(.bordered)
                    .accessibilityHint("Opens exercises filtered to cardio")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityAddTraits(.isHeader)
    }
}

#if DEBUG
#Preview("Cardio empty — light") {
    CardioEmptyStateView(onPrimary: {}, onSecondary: {})
        .padding()
}

#Preview("Cardio empty — dark", traits: .sizeThatFitsLayout) {
    CardioEmptyStateView(onPrimary: {}, onSecondary: {})
        .padding()
        .preferredColorScheme(.dark)
}
#endif
