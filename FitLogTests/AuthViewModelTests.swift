//
//  AuthViewModelTests.swift
//  FitLogTests
//

import Foundation
import SwiftData
import Testing
@testable import FitLog

@Suite(.serialized)
struct AuthViewModelTests {

    @Test @MainActor func deleteAccount_clearsSignInIdentity() throws {
        let container = try makeInMemoryContainer()
        let dataVM = DataManager(modelContainer: container)
        let currentVM = CurrentWorkoutSessionViewModel(dataManager: dataVM)
        let entitlements = EntitlementStore()
        let auth = AuthViewModel()

        auth.setSignedInForTesting(userID: "apple-user-1", email: "hide@example.com", name: "Reviewer")
        #expect(auth.isLoggedIn)
        #expect(auth.revenueCatAppUserID == "apple-user-1")

        auth.deleteAccount(
            dataManager: dataVM,
            currentWorkout: currentVM,
            entitlementStore: entitlements
        )

        #expect(!auth.isLoggedIn)
        #expect(!auth.usesLocalOnlyMode)
        #expect(auth.revenueCatAppUserID == nil)
        #expect(auth.userEmail.isEmpty)
        #expect(auth.userName.isEmpty)
    }

    @Test @MainActor func deleteAccount_erasesLocalUserData() throws {
        let container = try makeInMemoryContainer()
        let dataVM = DataManager(modelContainer: container)
        let currentVM = CurrentWorkoutSessionViewModel(dataManager: dataVM)
        let conversationID = dataVM.coachChatStore.createConversation(title: "Account data")
        #expect(dataVM.coachChatStore.appendMessage(
            CoachChatMessage(role: .user, text: "Hello"),
            conversationID: conversationID
        ))
        #expect(!dataVM.coachChatStore.loadConversations().isEmpty)

        let auth = AuthViewModel()
        auth.setSignedInForTesting(userID: "apple-user-2")
        auth.deleteAccount(
            dataManager: dataVM,
            currentWorkout: currentVM,
            entitlementStore: EntitlementStore()
        )

        #expect(dataVM.coachChatStore.loadConversations().isEmpty)
        #expect(!auth.isLoggedIn)
    }

    @Test @MainActor func logout_keepsLocalWorkoutData() throws {
        let container = try makeInMemoryContainer()
        let dataVM = DataManager(modelContainer: container)
        let conversationID = dataVM.coachChatStore.createConversation(title: "Keep me")
        #expect(dataVM.coachChatStore.appendMessage(
            CoachChatMessage(role: .user, text: "Stay"),
            conversationID: conversationID
        ))

        let auth = AuthViewModel()
        auth.setSignedInForTesting(userID: "apple-user-3")
        auth.logout()

        #expect(!auth.isLoggedIn)
        #expect(!dataVM.coachChatStore.loadConversations().isEmpty)
    }

    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: FitLogSchemaV6.self)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }
}
