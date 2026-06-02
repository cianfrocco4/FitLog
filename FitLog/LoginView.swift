//
//  LoginView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                Text("The Workout Log")
                    .font(.largeTitle.bold())

                Text("Track workouts on your device. Sign in with Apple is optional.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            authVM.handleAppleSignIn(credential: credential)
                        }
                    case .failure(let error):
                        let code = (error as? ASAuthorizationError)?.code
                        if code != .canceled {
                            authVM.errorMessage = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal, 40)
                .accessibilityLabel("Sign in with Apple")

                Button("Continue without signing in") {
                    authVM.continueWithoutSignIn()
                }
                .font(.subheadline.weight(.medium))
                .accessibilityLabel("Continue without signing in")
                .accessibilityHint("Uses the app locally without an Apple ID account")

                if let message = authVM.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
