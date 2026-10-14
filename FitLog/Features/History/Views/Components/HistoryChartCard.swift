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
                    .accessibilityIdentifier(FitLogA11yID.historyChartCard.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last cardio duration from a completed session")
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

    /// Cardio volume charts show last duration; other History charts stay caption-free.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        guard FernLastWorkingLoad.prefersLastCardioDuration(chartTitle: title) else { return nil }
        return FernLastWorkingLoad.lastCardioDurationCaption(from: dataManager.completedSessions)
    }
}

#Preview("Cardio volume") {
    HistoryChartCard(
        title: "Cardio volume",
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    ) {
        Text("Weekly minutes")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}

#Preview("Strength volume stays caption-free") {
    HistoryChartCard(
        title: "Volume by muscle",
        resolvesLastLoadFromEnvironment: false
    ) {
        Text("No last-load on strength charts")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
}
