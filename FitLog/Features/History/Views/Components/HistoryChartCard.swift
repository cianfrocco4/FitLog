//
//  HistoryChartCard.swift
//  FitLog
//

import SwiftUI

struct HistoryChartCard<Content: View>: View {
    let title: String
    var infoAction: (() -> Void)?
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true
    @ViewBuilder var content: () -> Content
    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                if let infoAction {
                    Button(action: infoAction) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Volume calculation info")
                }
            }
            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(FitLogA11yID.historyChart.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return JadeLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("History chart · last load") {
    HistoryChartCard(
        title: "Volume by muscle",
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    ) {
        Text("Chart")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }
    .padding()
    .environmentObject(UserPreferences())
}

#Preview("History chart · dark cardio") {
    HistoryChartCard(
        title: "Cardio volume",
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    ) {
        Text("Chart")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
    }
    .padding()
    .environmentObject(UserPreferences())
    .preferredColorScheme(.dark)
}
