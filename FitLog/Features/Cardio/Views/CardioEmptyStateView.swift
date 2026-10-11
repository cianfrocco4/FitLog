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
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run")
                .font(.system(size: 40))
                .foregroundStyle(FitlogPalette.chartSecondary)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headerAccessibilityLabel)
            .accessibilityAddTraits(.isHeader)
            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(FitLogA11yID.cardioEmpty.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
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
    }

    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return RowanLastWorkingLoad.lastCardioDurationCaption(
            from: dataManager.completedSessions
        )
    }

    private var headerAccessibilityLabel: String {
        if let lastLoad = resolvedLastLoadCaption {
            return "\(title). \(message). \(lastLoad)"
        }
        return "\(title). \(message)"
    }
}

#if DEBUG
#Preview("Cardio empty — light") {
    CardioEmptyStateView(
        onPrimary: {},
        onSecondary: {},
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
        .padding()
}

#Preview("Cardio empty — dark", traits: .sizeThatFitsLayout) {
    CardioEmptyStateView(
        onPrimary: {},
        onSecondary: {},
        resolvesLastLoadFromEnvironment: false
    )
        .padding()
        .preferredColorScheme(.dark)
}
#endif
