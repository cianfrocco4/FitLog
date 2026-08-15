//
//  PremiumGate.swift
//  FitLog
//
//  Reusable premium gating modifier and action helpers.
//

import SwiftUI

private struct PremiumGateModifier: ViewModifier {
    @Environment(EntitlementStore.self) private var entitlementStore

    let feature: PremiumFeature
    let style: PremiumGateStyle
    @Binding var showPaywall: Bool

    func body(content: Content) -> some View {
        if entitlementStore.hasAccess(to: feature) {
            content
        } else {
            switch style {
            case .overlay:
                content
                    .overlay { lockedOverlay }
                    .allowsHitTesting(false)
            case .replace:
                lockedCard
            case .none:
                content
            }
        }
    }

    private var lockedOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
            unlockButton
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var lockedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("\(feature.displayTitle) is Premium")
                .font(.headline)
            Text(feature.paywallBullet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            unlockButton
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var unlockButton: some View {
        Button {
            AnalyticsService.shared.track(.aiBlockedByPaywall, properties: ["feature": feature.rawValue])
            showPaywall = true
        } label: {
            Label("Unlock Premium", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.tint, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unlock Premium, \(feature.displayTitle)")
        .accessibilityHint("Shows subscription options for \(feature.displayTitle)")
    }
}

enum PremiumGateStyle {
    case overlay
    case replace
    case none
}

extension View {
    func premiumGated(_ feature: PremiumFeature, style: PremiumGateStyle = .overlay, showPaywall: Binding<Bool>) -> some View {
        modifier(PremiumGateModifier(feature: feature, style: style, showPaywall: showPaywall))
    }
}

/// Call before premium actions; returns true if allowed, otherwise sets `showPaywall`.
@MainActor
func requirePremiumOrPaywall(
    feature: PremiumFeature,
    entitlementStore: EntitlementStore,
    showPaywall: Binding<Bool>
) -> Bool {
    if entitlementStore.requirePremium(for: feature) { return true }
    AnalyticsService.shared.track(.aiBlockedByPaywall, properties: ["feature": feature.rawValue])
    showPaywall.wrappedValue = true
    return false
}
