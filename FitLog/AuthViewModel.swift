//
//  AuthViewModel.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//


import Foundation
import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @AppStorage("username") var username: String = ""
    
    func login(email: String, password: String) { username = email; isLoggedIn = true }
    func signUp(email: String, password: String) { username = email; isLoggedIn = true }
    func logout() { isLoggedIn = false }
}
