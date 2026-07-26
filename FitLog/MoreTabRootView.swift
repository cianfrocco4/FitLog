//
//  MoreTabRootView.swift
//  FitLog
//
//  Secondary destinations (exercise library, data settings) to keep the tab bar at five items.
//

import SwiftUI

struct MoreTabRootView: View {
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var userPreferences: UserPreferences
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var showEraseDataConfirm = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    PersonalRecordsView()
                        .environment(dataVM)
                        .environmentObject(userPreferences)
                } label: {
                    Label("Personal records", systemImage: "trophy.fill")
                }
                NavigationLink {
                    BodyMeasurementsView()
                        .environment(dataVM)
                        .environmentObject(userPreferences)
                } label: {
                    Label("Body measurements", systemImage: "figure.stand")
                }
                NavigationLink {
                    ProgressPhotosView()
                        .environment(dataVM)
                } label: {
                    Label("Progress photos", systemImage: "photo.on.rectangle.angled")
                }
                NavigationLink {
                    ExercisesLibraryView()
                } label: {
                    Label("Exercise Library", systemImage: "books.vertical")
                }
                NavigationLink {
                    SubscriptionSettingsView()
                        .environmentObject(authVM)
                } label: {
                    Label("Subscription", systemImage: "sparkles")
                }
                NavigationLink {
                    DataAndIntegrationsView()
                        .environmentObject(userPreferences)
                } label: {
                    Label("Data & Integrations", systemImage: "gearshape")
                }

                Section {
                    if authVM.isLoggedIn {
                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            authVM.logout(entitlementStore: entitlementStore)
                        }
                        .accessibilityHint("Signs out of your account")
                    } else if authVM.usesLocalOnlyMode {
                        Button("Sign in with Apple", systemImage: "person.crop.circle.badge.plus") {
                            authVM.logout()
                        }
                        .accessibilityHint("Returns to the sign-in screen")
                    }

                    Button("Erase all app data", systemImage: "trash", role: .destructive) {
                        showEraseDataConfirm = true
                    }
                    .accessibilityHint("Deletes workouts, history, programs, and personal records from this device")
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Erase all app data?",
                isPresented: $showEraseDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Erase everything", role: .destructive) {
                    currentVM.cancelWorkout()
                    dataVM.eraseAllAppData()
                    authVM.logout()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes workouts, history, programs, and personal records from this device. Export a backup first if you need one.")
            }
        }
    }
}
