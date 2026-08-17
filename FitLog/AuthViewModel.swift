//
//  AuthViewModel.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import Foundation
import SwiftUI
import AuthenticationServices

final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var errorMessage: String?

    @AppStorage("appleUserIdentifier") private var appleUserIdentifier: String = ""
    @AppStorage("appleUserEmail") var userEmail: String = ""
    @AppStorage("appleUserName") var userName: String = ""
    @AppStorage("fitlogUsesLocalOnlyMode") private var usesLocalOnlyModeStorage = false

    /// True when the user skipped Sign in with Apple and uses the app locally only.
    var usesLocalOnlyMode: Bool {
        usesLocalOnlyModeStorage && !isLoggedIn
    }

    init() {
#if DEBUG
        if FitLogUITestLaunch.isActive {
            // Avoid ASAuthorizationAppleIDProvider network/credential callbacks on CI simulators.
            isLoggedIn = true
            return
        }
#endif
        if usesLocalOnlyModeStorage && appleUserIdentifier.isEmpty {
            return
        }
        checkCredentialStateIfNeeded()
    }

    /// Continue without Sign in with Apple (local-only mode).
    func continueWithoutSignIn() {
        usesLocalOnlyModeStorage = true
        isLoggedIn = false
        errorMessage = nil
    }

    /// Stable identifier used as the RevenueCat App User ID for promotional entitlements.
    var revenueCatAppUserID: String? {
        let id = appleUserIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? nil : id
    }

    /// Call after Sign in with Apple succeeds (from LoginView's onCompletion).
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential, entitlementStore: EntitlementStore? = nil) {
        usesLocalOnlyModeStorage = false
        appleUserIdentifier = credential.user
        if let email = credential.email { userEmail = email }
        if let name = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            userName = formatter.string(from: name)
        }
        isLoggedIn = true
        errorMessage = nil
        if let entitlementStore {
            Task { await entitlementStore.logIn(appUserID: credential.user) }
        }
    }

    func logout(entitlementStore: EntitlementStore? = nil) {
        clearAccountIdentity()
        if let entitlementStore {
            Task { await entitlementStore.logOut() }
        }
    }

    /// Permanently deletes the Sign in with Apple account on this device and all locally stored user data.
    /// Does not cancel App Store subscriptions (Apple bills those) or remove Health samples already written to Apple Health.
    @MainActor
    func deleteAccount(
        dataManager: DataManager,
        currentWorkout: CurrentWorkoutSessionViewModel,
        entitlementStore: EntitlementStore
    ) async {
        currentWorkout.cancelWorkout()
        dataManager.eraseAllAppData(createSafetyBackup: false)
        dataManager.purgeRotatingUserBackups()
        clearAccountIdentity()
        await entitlementStore.logOut()
    }

    private func clearAccountIdentity() {
        appleUserIdentifier = ""
        userEmail = ""
        userName = ""
        isLoggedIn = false
        usesLocalOnlyModeStorage = false
        errorMessage = nil
    }

#if DEBUG
    func setSignedInForTesting(userID: String, email: String = "", name: String = "") {
        appleUserIdentifier = userID
        userEmail = email
        userName = name
        usesLocalOnlyModeStorage = false
        isLoggedIn = true
        errorMessage = nil
    }
#endif

    private func checkCredentialStateIfNeeded() {
        guard !appleUserIdentifier.isEmpty else {
            isLoggedIn = false
            return
        }
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: appleUserIdentifier) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized, .transferred:
                    self?.isLoggedIn = true
                case .revoked, .notFound:
                    self?.logout()
                @unknown default:
                    self?.isLoggedIn = false
                }
            }
        }
    }
}
