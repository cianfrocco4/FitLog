//
//  AccountSettingsView.swift
//  FitLog
//
//  Sign out and Guideline 5.1.1(v) account deletion for Sign in with Apple users.
//

import SwiftData
import SwiftUI

enum AccountDeletionAlert {
    static let title = "Delete Account?"
    static let message = "This permanently deletes your account and all Workout Log AI data on this device. It cannot be undone. App Store subscriptions are billed by Apple and are not canceled automatically — manage them in iOS Settings. Workouts already saved to Apple Health stay in Health."
}

struct DeleteAccountButton: View {
    @Binding var isConfirmationPresented: Bool
    var showsSystemImage: Bool = true

    var body: some View {
        Button(role: .destructive) {
            isConfirmationPresented = true
        } label: {
            if showsSystemImage {
                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
            } else {
                Text("Delete Account")
            }
        }
        .accessibilityLabel("Delete Account")
        .accessibilityHint("Permanently deletes your account and all Workout Log AI data on this device")
        .accessibilityAddTraits(.isButton)
    }
}

extension View {
    func deleteAccountConfirmation(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        self.alert(AccountDeletionAlert.title, isPresented: isPresented) {
            Button("Delete Account", role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AccountDeletionAlert.message)
        }
    }
}

struct AccountSettingsView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                LabeledContent("Sign-in") {
                    Text("Sign in with Apple")
                }
                if !authVM.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Name") {
                        Text(authVM.userName)
                    }
                }
                if !authVM.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LabeledContent("Email") {
                        Text(authVM.userEmail)
                    }
                }
            } footer: {
                Text("Sign in is optional. Workout data stays on this device.")
            }

            Section {
                Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    authVM.logout(entitlementStore: entitlementStore)
                }
                .accessibilityLabel("Sign Out")
                .accessibilityHint("Signs out of Sign in with Apple. Workouts stay on this device.")
                .accessibilityAddTraits(.isButton)
            }

            Section {
                DeleteAccountButton(isConfirmationPresented: $showDeleteConfirmation)
            } footer: {
                Text("Delete Account permanently removes your Sign in with Apple details stored in Workout Log AI and all workouts, history, programs, Coach chats, readiness, body metrics, and progress photos on this device. This cannot be undone. App Store subscriptions are billed by Apple and are not canceled automatically — manage or cancel in iOS Settings or Subscription before deleting if needed. Workouts already saved to Apple Health stay in Health.")
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .deleteAccountConfirmation(isPresented: $showDeleteConfirmation) {
            Task {
                await authVM.deleteAccount(
                    dataManager: dataVM,
                    currentWorkout: currentVM,
                    entitlementStore: entitlementStore
                )
            }
        }
        .sensoryFeedback(.warning, trigger: showDeleteConfirmation)
    }
}

#if DEBUG
@MainActor
private enum AccountSettingsPreviewData {
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

#Preview("Account") {
    let dataVM = AccountSettingsPreviewData.dataManager()
    NavigationStack {
        AccountSettingsView()
            .environment(dataVM)
            .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
            .environmentObject(AuthViewModel())
            .environment(EntitlementStore())
    }
}

#Preview("Account Dark") {
    let dataVM = AccountSettingsPreviewData.dataManager()
    NavigationStack {
        AccountSettingsView()
            .environment(dataVM)
            .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
            .environmentObject(AuthViewModel())
            .environment(EntitlementStore())
    }
    .preferredColorScheme(.dark)
}

#Preview("Account XL") {
    let dataVM = AccountSettingsPreviewData.dataManager()
    NavigationStack {
        AccountSettingsView()
            .environment(dataVM)
            .environment(CurrentWorkoutSessionViewModel(dataManager: dataVM))
            .environmentObject(AuthViewModel())
            .environment(EntitlementStore())
    }
    .dynamicTypeSize(.accessibility2)
}
