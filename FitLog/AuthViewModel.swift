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
    
    init() {
        if FitLogUITestLaunch.isActive {
            // Avoid ASAuthorizationAppleIDProvider network/credential callbacks on CI simulators.
            isLoggedIn = true
            return
        }
        checkCredentialStateIfNeeded()
    }
    
    /// Call after Sign in with Apple succeeds (from LoginView's onCompletion).
    func handleAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        appleUserIdentifier = credential.user
        if let email = credential.email { userEmail = email }
        if let name = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            userName = formatter.string(from: name)
        }
        isLoggedIn = true
        errorMessage = nil
    }
    
    func logout() {
        appleUserIdentifier = ""
        userEmail = ""
        userName = ""
        isLoggedIn = false
        errorMessage = nil
    }
    
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
