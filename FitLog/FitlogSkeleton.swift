//
//  FitlogSkeleton.swift
//  FitLog
//
//  Lightweight shimmer placeholders for first paint on heavy tabs.
//

import SwiftUI

private struct FitlogShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.primary.opacity(0.12),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 1.8)
                    .offset(x: -w * 0.9 + phase * w * 1.8)
                    .mask(content)
                }
            }
            .onAppear {
                phase = 0
                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func fitlogShimmering() -> some View {
        modifier(FitlogShimmerModifier())
    }
}

// MARK: - Placeholder shapes

struct FitlogSkeletonLine: View {
    var widthFraction: CGFloat = 1
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.primary.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .fitlogShimmering()
            .padding(.trailing, max(0, (1 - widthFraction)) * 120)
    }
}

struct FitlogSkeletonCardBlock: View {
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(DataManager.self) private var dataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lastLoad = resolvedLastLoadCaption {
                Text(lastLoad)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(FitLogA11yID.homeSkeleton.lastLoad)
                    .accessibilityLabel(lastLoad)
                    .accessibilityHint("Last working set or last cardio duration from a completed session")
                    .accessibilityAddTraits(.isStaticText)
            }
            FitlogSkeletonLine(widthFraction: 0.35, height: 12)
            FitlogSkeletonLine(widthFraction: 0.9, height: 22)
            FitlogSkeletonLine(widthFraction: 0.7, height: 14)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 72)
                        .frame(maxWidth: .infinity)
                        .fitlogShimmering()
                }
            }
        }
        .padding()
        .background(FitlogPalette.subtleFill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return OliveLastWorkingLoad.newestCompletedCaption(
            from: dataManager.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

struct FitlogHistoryKPISkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FitlogSkeletonLine(widthFraction: 0.4, height: 12)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 88)
                        .frame(maxWidth: .infinity)
                        .fitlogShimmering()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("Home skeleton · last load") {
    FitlogSkeletonCardBlock(
        lastLoadCaption: "Last 185 lb × 8 reps",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("Home skeleton · dark cardio") {
    FitlogSkeletonCardBlock(
        lastLoadCaption: "Last 45:00",
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
