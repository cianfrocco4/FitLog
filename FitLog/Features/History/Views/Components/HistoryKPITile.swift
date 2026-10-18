//
//  HistoryKPITile.swift
//  FitLog
//

import SwiftUI

struct HistoryKPITile: View {
    let title: String
    let value: String
    let deltaLine: (String, Color)?
    let systemImage: String
    var showsInfoButton = false
    var onInfo: (() -> Void)?
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                if showsInfoButton, let onInfo {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Volume calculation info")
                }
            }
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            if let deltaLine {
                Text(deltaLine.0)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(deltaLine.1)
            }
            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(FitLogA11yID.historyKPI.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .accessibilityElement(children: .combine)
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    /// Only the Sessions tile shows it so the six-tile grid does not repeat the same caption.
    private var resolvedLastLoadCaption: String? {
        guard title == "Sessions" else { return nil }
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return CoralLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("Sessions · last load") {
    HistoryKPITile(
        title: "Sessions",
        value: "12",
        deltaLine: nil,
        systemImage: "figure.strengthtraining.traditional",
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .environmentObject(UserPreferences())
    .padding()
}

#Preview("Sessions · dark cardio") {
    HistoryKPITile(
        title: "Sessions",
        value: "8",
        deltaLine: ("+2", .green),
        systemImage: "figure.strengthtraining.traditional",
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
    .environmentObject(UserPreferences())
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Volume · no last load") {
    HistoryKPITile(
        title: "Volume",
        value: "48k lb·rep",
        deltaLine: nil,
        systemImage: "scalemass.fill",
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .environmentObject(UserPreferences())
    .padding()
}
