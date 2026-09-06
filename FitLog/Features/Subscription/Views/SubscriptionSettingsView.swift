//
//  SubscriptionSettingsView.swift
//  FitLog
//
//  Subscription status, restore/refresh, and App User ID for developer comp access.
//

import SwiftData
import SwiftUI
import StoreKit
import UIKit

struct SubscriptionSettingsView: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var showPaywall = false
    @State private var copiedUserID = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            if GlanceLastSessionWorkingCopy.latestCompletedSession(in: dataVM.completedSessions) != nil {
                Section {
                    GlanceLastSessionHost(
                        recapIdentifier: FitLogA11yID.subscriptionSettingsLastSession,
                        startIdentifier: FitLogA11yID.subscriptionSettingsStartThisWorkout,
                        caption: "You can train without opening Premium. Upgrade stays below.",
                        startProminent: true
                    )
                }
            }

            Section {
                HStack {
                    Label("Premium", systemImage: entitlementStore.isPremium ? "checkmark.seal.fill" : "lock.fill")
                    Spacer()
                    Text(premiumStatusTitle)
                        .foregroundStyle(entitlementStore.isPremium ? .green : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Premium status, \(premiumStatusTitle)")

                if entitlementStore.isPremium {
                    Text(premiumStatusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(premiumStatusDetail)
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Upgrade to Premium", systemImage: "sparkles")
                    }
                }
            }

            Section("Manage") {
                if entitlementStore.isPremium {
                    Button {
                        Task { await openManageSubscriptions() }
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                    .accessibilityHint("Opens App Store subscription management")
                }

                Button {
                    Task {
                        let refreshed = await entitlementStore.syncPurchases()
                        if refreshed || entitlementStore.isPremium {
                            statusMessage = premiumRefreshMessage
                            AnalyticsService.shared.track(.restoreCompleted, properties: ["source": "settings"])
                        } else {
                            statusMessage = entitlementStore.lastErrorMessage ?? "No active premium access found."
                            AnalyticsService.shared.track(
                                .restoreFailed,
                                properties: [
                                    "source": "settings",
                                    "reason": entitlementStore.lastErrorMessage ?? "no_active_subscription"
                                ]
                            )
                        }
                    }
                } label: {
                    if entitlementStore.isRestoring {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(SubscriptionRestoreAccessibility.restoringCaption)
                        }
                    } else {
                        Label(SubscriptionRestoreAccessibility.settingsIdleLabel, systemImage: "arrow.clockwise")
                    }
                }
                .disabled(entitlementStore.isRestoring)
                .accessibilityLabel(
                    SubscriptionRestoreAccessibility.restoreLabel(
                        isRestoring: entitlementStore.isRestoring,
                        idleLabel: SubscriptionRestoreAccessibility.settingsIdleLabel
                    )
                )
                .accessibilityHint(SubscriptionRestoreAccessibility.settingsHint)
            }

            Section {
                if let appUserID = entitlementStore.appUserID {
                    LabeledContent("App User ID") {
                        Text(appUserID)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .multilineTextAlignment(.trailing)
                    }

                    Button {
                        UIPasteboard.general.string = appUserID
                        copiedUserID = true
                    } label: {
                        Label(copiedUserID ? "Copied" : "Copy App User ID", systemImage: "doc.on.doc")
                    }
                }

                Text("Send your App User ID to support if you were granted complimentary premium access. Access is applied securely through RevenueCat — it cannot be unlocked from the device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if authVM.usesLocalOnlyMode {
                    Text("Sign in with Apple for a stable App User ID tied to your Apple account.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Support access")
            }

            Section {
                LegalLinkRow(link: .termsOfUse)
                LegalLinkRow(link: .privacyPolicy)
            } header: {
                Text("Legal")
            } footer: {
                Text("Not medical advice — general fitness coaching tool only. Terms of Use is Apple’s Standard Licensed Application EULA.")
            }
        }
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: nil)
                .environment(entitlementStore)
        }
        .alert("Subscription", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
        .onChange(of: copiedUserID) { _, copied in
            guard copied else { return }
            Task {
                try? await Task.sleep(for: .seconds(2))
                copiedUserID = false
            }
        }
    }

    private var details: PremiumAccessDetails {
        entitlementStore.premiumDetails
    }

    private var premiumStatusTitle: String {
        guard details.isActive else { return "Free" }
        if details.isPromotional { return "Active (comp)" }
        if !details.willRenew { return "Active (canceled)" }
        return "Active"
    }

    private var premiumStatusDetail: String {
        guard details.isActive else { return "" }
        if details.isPromotional {
            if let expirationDate = details.expirationDate {
                return "Complimentary access through \(expirationDate.formatted(date: .abbreviated, time: .omitted))."
            }
            return "Complimentary Premium access via RevenueCat."
        }
        if !details.willRenew {
            if let expirationDate = details.expirationDate {
                return "Auto-renew is off. You keep Premium until \(expirationDate.formatted(date: .abbreviated, time: .shortened))."
            }
            return "Auto-renew is off. You keep Premium until the current period ends."
        }
        if let expirationDate = details.expirationDate {
            return "Renews \(expirationDate.formatted(date: .abbreviated, time: .shortened)). Thank you for supporting Workout Log AI."
        }
        return "Thank you for supporting Workout Log AI."
    }

    private var premiumRefreshMessage: String {
        guard details.isActive else { return "Premium access is active." }
        if !details.willRenew, !details.isPromotional {
            if let expirationDate = details.expirationDate {
                return "Subscription canceled. Premium stays active until \(expirationDate.formatted(date: .abbreviated, time: .shortened))."
            }
            return "Subscription canceled. Premium stays active until the current period ends."
        }
        return "Premium access is active."
    }

    @MainActor
    private func openManageSubscriptions() async {
        AnalyticsService.shared.track(.manageSubscriptionOpened)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }
}

#if DEBUG
@MainActor
private enum SubscriptionSettingsPreviewData {
    static func dataManager() -> DataManager {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let container = try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return DataManager(modelContainer: container)
    }
}
#endif

#Preview("Subscription settings") {
    let dataVM = SubscriptionSettingsPreviewData.dataManager()
    NavigationStack {
        SubscriptionSettingsView()
            .environment(EntitlementStore())
            .environment(dataVM)
            .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
            .environmentObject(AuthViewModel())
            .environmentObject(UserPreferences())
    }
}

#Preview("Subscription settings Dark") {
    let dataVM = SubscriptionSettingsPreviewData.dataManager()
    NavigationStack {
        SubscriptionSettingsView()
            .environment(EntitlementStore())
            .environment(dataVM)
            .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
            .environmentObject(AuthViewModel())
            .environmentObject(UserPreferences())
    }
    .preferredColorScheme(.dark)
}
