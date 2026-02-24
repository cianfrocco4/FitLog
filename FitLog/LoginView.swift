//
//  LoginView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "dumbbell.fill").font(.system(size: 80)).foregroundStyle(.blue)
                Text(isSignUp ? "Create Account" : "Welcome Back").font(.largeTitle.bold())
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email).textFieldStyle(.roundedBorder).autocapitalization(.none)
                    SecureField("Password", text: $password).textFieldStyle(.roundedBorder)
                }.padding(.horizontal)
                
                Button(isSignUp ? "Sign Up" : "Login") {
                    if isSignUp { authVM.signUp(email: email, password: password) } else { authVM.login(email: email, password: password) }
                }.buttonStyle(.borderedProminent).controlSize(.large)
                
                Button(isSignUp ? "Already have an account? Login" : "Need an account? Sign Up") { isSignUp.toggle() }.foregroundStyle(.blue)
            }.padding()
        }
    }
}
