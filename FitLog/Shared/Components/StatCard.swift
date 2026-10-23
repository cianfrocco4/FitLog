//
//  StatCard.swift
//  FitLog
//
//  Reusable stat display card for consistency (Task 28).
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String?
    let accentColor: Color
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    init(
        title: String,
        value: String,
        systemImage: String? = nil,
        accentColor: Color = .accentColor,
        lastLoadCaption: String? = nil,
        resolvesLastLoadFromEnvironment: Bool = true
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.lastLoadCaption = lastLoadCaption
        self.resolvesLastLoadFromEnvironment = resolvesLastLoadFromEnvironment
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return QuartzLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .accessibilityHidden(true)
            }

            Text(value)
                .font(.title.weight(.semibold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(FitLogA11yID.statCard.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(FitlogPalette.subtleFill)
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview("Single Stat") {
    StatCard(
        title: "Total Sets",
        value: "42",
        systemImage: "dumbbell.fill",
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("Multiple Stats") {
    HStack(spacing: 12) {
        StatCard(
            title: "Weekly",
            value: "30",
            systemImage: "calendar",
            accentColor: .blue,
            lastLoadCaption: "Last 185 lb × 8 reps",
            resolvesLastLoadFromEnvironment: false
        )
        StatCard(
            title: "Personal Best",
            value: "225",
            systemImage: "trophy.fill",
            accentColor: FitlogPalette.highlight,
            lastLoadCaption: "Last 45:00",
            resolvesLastLoadFromEnvironment: false
        )
    }
    .padding()
}
