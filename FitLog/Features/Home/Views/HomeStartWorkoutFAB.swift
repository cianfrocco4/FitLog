//
//  HomeStartWorkoutFAB.swift
//  FitLog
//
//  Sticky primary action to start a workout from Home.
//

import SwiftUI

struct HomeStartWorkoutFAB: View {
    let isWorkoutActive: Bool
    let onTap: () -> Void
    /// Last working load or last cardio duration from the newest completed session.
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a `DataManager` environment.
    var resolvesLastLoadFromEnvironment: Bool = true

    @State private var tapSerial = 0

    var body: some View {
        if !isWorkoutActive {
            VStack(spacing: 8) {
                Button {
                    tapSerial += 1
                    onTap()
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 4)
                .accessibilityIdentifier(FitLogA11yID.startWorkout)
                .accessibilityLabel("Start workout")
                .accessibilityHint("Opens options to start a workout")
                .accessibilityAddTraits(.isButton)
                .sensoryFeedback(.impact(weight: .medium), trigger: tapSerial)

                if let lastLoadCaption, !lastLoadCaption.isEmpty {
                    lastLoadLine(lastLoadCaption)
                } else if resolvesLastLoadFromEnvironment {
                    HomeStartFABLastLoadCaption()
                }
            }
        }
    }

    private func lastLoadLine(_ caption: String) -> some View {
        Text(caption)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityIdentifier(FitLogA11yID.homeStartFAB.lastLoad)
            .accessibilityLabel(caption)
            .accessibilityHint("Last working set or last cardio duration from a completed session")
    }
}

private struct HomeStartFABLastLoadCaption: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        if let lastLoad = CypressLastWorkingLoad.newestCompletedCaption(
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        ) {
            Text(lastLoad)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier(FitLogA11yID.homeStartFAB.lastLoad)
                .accessibilityLabel(lastLoad)
                .accessibilityHint("Last working set or last cardio duration from a completed session")
        }
    }
}

#Preview("Start FAB") {
    HomeStartWorkoutFAB(
        isWorkoutActive: false,
        onTap: {},
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("Start FAB — dark") {
    HomeStartWorkoutFAB(
        isWorkoutActive: false,
        onTap: {},
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Start FAB — large type") {
    HomeStartWorkoutFAB(
        isWorkoutActive: false,
        onTap: {},
        lastLoadCaption: "Last 100 kg × 5 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
    .dynamicTypeSize(.accessibility3)
}
