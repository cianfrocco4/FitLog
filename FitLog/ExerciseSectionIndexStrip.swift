//
//  ExerciseSectionIndexStrip.swift
//  FitLog
//

import SwiftUI

struct ExerciseSectionIndexStrip: View {
    let proxy: ScrollViewProxy
    let ids: [String]
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return OpalLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }

    var body: some View {
        VStack(spacing: 2) {
            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .frame(width: 36)
                    .accessibilityIdentifier(FitLogA11yID.exerciseIndex.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
                    .padding(.bottom, 4)
            }
            ForEach(ids, id: \.self) { id in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                } label: {
                    Text(Self.indexLabel(for: id))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Jump to \(Self.indexAccessibilityLabel(for: id))")
                .accessibilityHint("Scrolls the exercise list to this section")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 4)
    }

    private static func indexAccessibilityLabel(for id: String) -> String {
        switch id {
        case "favorites": return "favorites"
        case "recent": return "recent"
        default: return String(id.prefix(1)).uppercased()
        }
    }

    private static func indexLabel(for id: String) -> String {
        switch id {
        case "favorites": return "★"
        case "recent": return "○"
        default: return String(id.prefix(1)).uppercased()
        }
    }
}

#Preview("Exercise index last load · strength") {
    ScrollViewReader { proxy in
        ExerciseSectionIndexStrip(
            proxy: proxy,
            ids: ["favorites", "recent", "c", "s"],
            lastLoadCaption: "Last 185 lb × 8 reps",
            resolvesLastLoadFromEnvironment: false
        )
    }
    .padding()
}

#Preview("Exercise index last load · dark cardio") {
    ScrollViewReader { proxy in
        ExerciseSectionIndexStrip(
            proxy: proxy,
            ids: ["favorites", "recent", "c", "s"],
            lastLoadCaption: "Last 45:00",
            resolvesLastLoadFromEnvironment: false
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
