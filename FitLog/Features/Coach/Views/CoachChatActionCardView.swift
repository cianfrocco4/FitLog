//
//  CoachChatActionCardView.swift
//  FitLog
//
//  Confirmation-gated action cards under assistant messages.
//

import SwiftUI

struct CoachChatActionCardView: View {
    let action: CoachChatAction
    let onApply: () -> Void
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(action.title, systemImage: iconName)
                .font(.subheadline.weight(.semibold))

            if let detail = action.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(FitLogA11yID.coachActionCard.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }

            if action.isApplied {
                Label("Applied", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.success)
            } else {
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint("Confirm and apply this suggestion")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch action.kind {
        case .openProgramBuilder: return "calendar.badge.clock"
        case .openPlanTab: return "calendar"
        case .openHomeTab: return "house"
        }
    }

    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return RowanLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("Open program — light") {
    CoachChatActionCardView(
        action: CoachChatAction(
            kind: .openProgramBuilder,
            title: "Build this split",
            detail: "Open the program builder with a 4-day push/pull draft."
        ),
        onApply: {},
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("Applied — dark") {
    CoachChatActionCardView(
        action: CoachChatAction(
            kind: .openHomeTab,
            title: "Start from Home",
            detail: "Jump to Home to log today’s session.",
            isApplied: true
        ),
        onApply: {},
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
