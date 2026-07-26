//
//  SubscriptionSettingsView.swift
//  FitLog
//
//  Subscription status, restore/refresh, and App User ID for developer comp access.
//

import SwiftUI
import StoreKit
import UIKit

struct SubscriptionSettingsView: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var showPaywall = false
    @State private var copiedUserID = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Label("Premium", systemImage: entitlementStore.isPremium ? "checkmark.seal.fill" : "lock.fill")
                    Spacer()
                    Text(entitlementStore.isPremium ? "Active" : "Free")
                        .foregroundStyle(entitlementStore.isPremium ? .green : .secondary)
                }

                if entitlementStore.isPremium {
                    Text("Thank you for supporting Workout Log AI.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        if refreshed {
                            statusMessage = "Premium access is active."
                            AnalyticsService.shared.track(.restoreCompleted, properties: ["source": "settings"])
                        } else if entitlementStore.isPremium {
                            statusMessage = "Premium access is active."
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
                    Label("Restore / Refresh access", systemImage: "arrow.clockwise")
                }
                .disabled(entitlementStore.isRestoring)

                if entitlementStore.isRestoring {
                    ProgressView()
                }
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
                Text("Not medical advice — general fitness coaching tool only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

#Preview {
    NavigationStack {
        SubscriptionSettingsView()
            .environment(EntitlementStore())
            .environmentObject(AuthViewModel())
    }
}
