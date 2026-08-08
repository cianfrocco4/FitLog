//
//  PaywallView.swift
//  FitLog
//
//  Value-first premium paywall for Workout Log AI.
//

import SwiftUI

#if canImport(RevenueCat)
import RevenueCat
#endif

private enum PaywallLegalURL {
    static let privacyPolicy = URL(string: "https://cianfrocco4.github.io/FitLog/privacy-policy.html")!
    static let eula = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

struct PaywallView: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss

    var triggerFeature: PremiumFeature?
    /// Analytics `source` for paywall_shown / paywall_dismissed (e.g. `post_workout`, `home_card`).
    var analyticsSource: String?
    var onDismiss: (() -> Void)?

    @State private var selectedPackageID: String?
    @State private var showRestoreSuccess = false
    @State private var alertMessage: String?

    private var canPurchase: Bool {
#if canImport(RevenueCat)
        RevenueCatConfig.isConfigured
            && !(entitlementStore.offerings?.current?.availablePackages.isEmpty ?? true)
#else
        false
#endif
    }

    private var paywallAnalyticsProperties: [String: String] {
        var props: [String: String] = [
            "feature": triggerFeature?.rawValue ?? "unknown"
        ]
        if let analyticsSource, !analyticsSource.isEmpty {
            props["source"] = analyticsSource
        }
        return props
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    benefitsSection
                    planSection
                    legalSection
                }
                .padding()
            }
            .navigationTitle("Workout Log AI Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        AnalyticsService.shared.track(.paywallDismissed, properties: paywallAnalyticsProperties)
                        onDismiss?()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                purchaseBar
            }
            .task {
                AnalyticsService.shared.track(.paywallShown, properties: paywallAnalyticsProperties)
                await entitlementStore.loadOfferings()
            }
            .alert("Subscription", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("Access restored", isPresented: $showRestoreSuccess) {
                Button("Continue") {
                    if entitlementStore.isPremium { dismiss() }
                }
            } message: {
                Text("Your premium access is active.")
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Train smarter. Recover better.")
                .font(.title.weight(.bold))

            Text("Unlock AI coaching, readiness trends, and advanced analytics — built for serious lifters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let triggerFeature {
                Text("Unlock \(triggerFeature.displayTitle) and everything below.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PremiumFeature.paywallHighlights) { feature in
                Label(feature.paywallBullet, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var unavailableMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Plans unavailable", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            Text("Workout logging and readiness stay free. Check your connection and try again in a moment. If this continues, contact support from the Support link in App Store or Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
#if DEBUG
            Text("DEBUG: Configure RevenueCat or attach a StoreKit configuration file for local purchase testing.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
#endif
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var planSection: some View {
#if canImport(RevenueCat)
        if entitlementStore.isLoadingOfferings {
            ProgressView("Loading plans…")
                .frame(maxWidth: .infinity)
        } else if let packages = entitlementStore.offerings?.current?.availablePackages, !packages.isEmpty {
            VStack(spacing: 10) {
                ForEach(packages, id: \.identifier) { package in
                    planRow(package: package)
                }
            }
            .onAppear {
                if selectedPackageID == nil {
                    selectedPackageID = packages.first?.identifier
                }
            }
        } else {
            // Single empty state — avoid stacking placeholderPlans + unavailableMessage.
            unavailableMessage
        }
#else
        unavailableMessage
#endif
    }

#if canImport(RevenueCat)
    private func planRow(package: Package) -> some View {
        let isSelected = selectedPackageID == package.identifier
        let priceLine = planPriceDisclosure(for: package)
        return Button {
            selectedPackageID = package.identifier
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.headline)
                    Text(priceLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString)
                    .font(.headline)
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(package.storeProduct.localizedTitle), \(priceLine)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func planPriceDisclosure(for package: Package) -> String {
        let product = package.storeProduct
        let price = product.localizedPriceString
        let period = subscriptionPeriodLabel(product.subscriptionPeriod)
        let recurring = period.map { "\(price)/\($0)" } ?? price

        guard let intro = product.introductoryDiscount else {
            return product.localizedDescription.isEmpty ? recurring : "\(recurring). \(product.localizedDescription)"
        }

        let eligible = entitlementStore.isIntroEligible(forProductID: product.productIdentifier)
        let introPeriod = subscriptionPeriodLabel(intro.subscriptionPeriod) ?? "intro period"
        if eligible, intro.paymentMode == .freeTrial {
            return "\(introPeriod) free, then \(recurring)"
        }
        if eligible, intro.paymentMode == .payUpFront {
            return "\(intro.localizedPriceString) for \(introPeriod), then \(recurring)"
        }
        if eligible, intro.paymentMode == .payAsYouGo {
            return "\(intro.localizedPriceString) for \(introPeriod), then \(recurring)"
        }
        return recurring
    }

    private func subscriptionPeriodLabel(_ period: SubscriptionPeriod?) -> String? {
        guard let period else { return nil }
        let value = period.value
        switch period.unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return nil
        }
    }
#endif

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not medical advice — general fitness coaching tool only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: PaywallLegalURL.privacyPolicy)
                Link("Apple Standard EULA", destination: PaywallLegalURL.eula)
            }
            .font(.caption)
        }
    }

    private var purchaseBar: some View {
        VStack(spacing: 10) {
#if canImport(RevenueCat)
            if canPurchase, let package = selectedPackage ?? entitlementStore.offerings?.current?.availablePackages.first {
                Button {
                    Task {
                        let success = await entitlementStore.purchase(package: package)
                        if success { dismiss() }
                        else if let msg = entitlementStore.lastErrorMessage { alertMessage = msg }
                    }
                } label: {
                    Group {
                        if entitlementStore.isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(ctaTitle(for: package))
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(entitlementStore.isPurchasing)
            }
#endif
            Button("Restore purchases") {
                Task {
                    let restored = await entitlementStore.restorePurchases()
                    if restored {
                        showRestoreSuccess = true
                        AnalyticsService.shared.track(.restoreCompleted, properties: ["source": "paywall"])
                    } else if let msg = entitlementStore.lastErrorMessage {
                        alertMessage = msg
                        AnalyticsService.shared.track(.restoreFailed, properties: ["source": "paywall", "reason": msg])
                    } else {
                        alertMessage = "No active subscription found for this Apple ID."
                        AnalyticsService.shared.track(.restoreFailed, properties: ["source": "paywall", "reason": "no_active_subscription"])
                    }
                }
            }
            .font(.footnote)
            .disabled(entitlementStore.isRestoring)
        }
        .padding()
        .background(.bar)
    }

#if canImport(RevenueCat)
    private var selectedPackage: Package? {
        guard let id = selectedPackageID else {
            return entitlementStore.offerings?.current?.availablePackages.first
        }
        return entitlementStore.offerings?.current?.availablePackages.first { $0.identifier == id }
    }

    private func ctaTitle(for package: Package) -> String {
        if package.packageType == .lifetime {
            return "Unlock lifetime access"
        }
        let product = package.storeProduct
        if let intro = product.introductoryDiscount,
           intro.paymentMode == .freeTrial,
           entitlementStore.isIntroEligible(forProductID: product.productIdentifier) {
            return "Start free trial"
        }
        return "Continue with Premium"
    }
#endif
}

#Preview("Paywall") {
    PaywallView(triggerFeature: .aiCoach)
        .environment(EntitlementStore())
}
