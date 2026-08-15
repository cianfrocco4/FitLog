//
//  PaywallView.swift
//  FitLog
//
//  Premium paywall using StoreKit SubscriptionStoreView (Guideline 3.1.2(c)).
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(\.dismiss) private var dismiss

    var triggerFeature: PremiumFeature?
    /// Analytics `source` for paywall_shown / paywall_dismissed (e.g. `post_workout`, `home_card`).
    var analyticsSource: String?
    var onDismiss: (() -> Void)?

    @State private var alertMessage: String?
    @State private var showRestoreSuccess = false
    @State private var storeProductsFailed = false
    @State private var didTrackDismiss = false

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
        SubscriptionStoreView(productIDs: SubscriptionCatalog.autoRenewableProductIDs) {
            marketingContent
        }
        .subscriptionStorePolicyDestination(url: LegalURLs.privacyPolicy, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: LegalURLs.termsOfUse, for: .termsOfService)
        // Built-in Restore only runs AppStore.sync() and will not sync RevenueCat.
        .storeButton(.hidden, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .onInAppPurchaseStart { product in
            let productID = product.id
            await MainActor.run {
                AnalyticsService.shared.track(.purchaseStarted, properties: ["product_id": productID])
            }
        }
        .onInAppPurchaseCompletion { _, result in
            await handlePurchaseCompletion(result)
        }
        .task {
            AnalyticsService.shared.track(.paywallShown, properties: paywallAnalyticsProperties)
            await loadStoreProducts()
            await entitlementStore.loadOfferings()
        }
        .task {
            for await verification in StoreKit.Transaction.updates {
                await handleStoreKitTransactionUpdate(verification)
            }
        }
        .onDisappear {
            trackDismissIfNeeded()
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

    private var marketingContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            heroSection
            benefitsSection
            if storeProductsFailed {
                staticPlanDisclosure
            }
            legalSection
        }
        .padding()
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
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
        .accessibilityElement(children: .combine)
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

    private var staticPlanDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Subscription options", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
            Text("Plans could not be loaded from the App Store right now. Purchase stays disabled until they appear. US list prices for Workout Log AI Premium:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(SubscriptionCatalog.autoRenewablePlans) { plan in
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.headline)
                    Text("\(plan.duration) · \(plan.listPriceUSD)")
                        .font(.subheadline)
                    Text(plan.disclosure)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(plan.title), \(plan.duration), \(plan.listPriceUSD). \(plan.disclosure)")
            }
            LegalLinksView(style: .compact)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not medical advice — general fitness coaching tool only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in iOS Settings or More → Subscription.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            LegalLinksView(style: .compact)
            Button {
                Task { await restorePurchasesFromPaywall() }
            } label: {
                if entitlementStore.isRestoring {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Restoring…")
                    }
                } else {
                    Text("Restore purchases")
                }
            }
            .font(.footnote)
            .disabled(entitlementStore.isRestoring)
            .accessibilityLabel(entitlementStore.isRestoring ? "Restoring purchases" : "Restore purchases")
            .accessibilityHint("Restores an existing Apple subscription and syncs Premium access")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func loadStoreProducts() async {
        do {
            let products = try await Product.products(for: Set(SubscriptionCatalog.autoRenewableProductIDs))
            storeProductsFailed = products.isEmpty
        } catch {
            storeProductsFailed = true
        }
    }

    @MainActor
    private func handlePurchaseCompletion(_ result: Result<Product.PurchaseResult, Error>) async {
        switch result {
        case .success(let purchaseResult):
            switch purchaseResult {
            case .success(let verification):
                AnalyticsService.shared.track(.purchaseCompleted)
                _ = await entitlementStore.syncPurchases()
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                if entitlementStore.isPremium {
                    dismiss()
                } else {
                    alertMessage = entitlementStore.lastErrorMessage
                        ?? "Purchase completed but Premium is not active yet. Use Restore purchases, or contact support with your App User ID."
                }
            case .userCancelled:
                AnalyticsService.shared.track(.purchaseCancelled)
            case .pending:
                alertMessage = "Your purchase is pending approval. Premium will unlock after Apple confirms the transaction."
            @unknown default:
                break
            }
        case .failure(let error):
            AnalyticsService.shared.track(.purchaseFailed, properties: ["message": error.localizedDescription])
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func restorePurchasesFromPaywall() async {
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

    @MainActor
    private func handleStoreKitTransactionUpdate(_ verification: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        let wasPremium = entitlementStore.isPremium
        _ = await entitlementStore.syncPurchases()
        await transaction.finish()
        if !wasPremium && entitlementStore.isPremium {
            dismiss()
        }
    }

    private func trackDismissIfNeeded() {
        guard !didTrackDismiss else { return }
        didTrackDismiss = true
        AnalyticsService.shared.track(.paywallDismissed, properties: paywallAnalyticsProperties)
        onDismiss?()
    }
}

#Preview("Paywall") {
    PaywallView(triggerFeature: .aiCoach)
        .environment(EntitlementStore())
}

#Preview("Paywall Dark") {
    PaywallView(triggerFeature: .aiCoach)
        .environment(EntitlementStore())
        .preferredColorScheme(.dark)
}

#Preview("Paywall iPad", traits: .fixedLayout(width: 834, height: 1194)) {
    PaywallView(triggerFeature: .readinessTrends)
        .environment(EntitlementStore())
}
