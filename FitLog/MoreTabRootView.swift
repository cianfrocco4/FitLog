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
    @State private var showDeleteAccountConfirm = false
    /// Injected caption skips the live session store (previews / tests).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    var body: some View {
        NavigationStack {
            List {
                if let lastLoad = resolvedLastLoadCaption {
                    Section {
                        Text(lastLoad)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(FitLogA11yID.moreTab.lastLoad)
                            .accessibilityLabel(lastLoad)
                            .accessibilityHint("Last working set or last cardio duration from a completed session")
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
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

                Section("Legal & Support") {
                    LegalLinkRow(link: .termsOfUse)
                    LegalLinkRow(link: .privacyPolicy)
                    LegalLinkRow(link: .support)
                }

                if authVM.isLoggedIn {
                    Section("Account") {
                        NavigationLink {
                            AccountSettingsView()
                                .environment(dataVM)
                                .environment(currentVM)
                                .environmentObject(authVM)
                                .environment(entitlementStore)
                        } label: {
                            Label("Account", systemImage: "person.crop.circle")
                        }
                        .accessibilityHint("Sign out or permanently delete your account")

                        DeleteAccountButton(isConfirmationPresented: $showDeleteAccountConfirm)

                        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            authVM.logout(entitlementStore: entitlementStore)
                        }
                        .accessibilityLabel("Sign Out")
                        .accessibilityHint("Signs out of your account. Workouts stay on this device.")
                        .accessibilityAddTraits(.isButton)
                    }
                } else if authVM.usesLocalOnlyMode {
                    Section {
                        Button("Sign in with Apple", systemImage: "person.crop.circle.badge.plus") {
                            authVM.logout()
                        }
                        .accessibilityHint("Returns to the sign-in screen")
                        .accessibilityAddTraits(.isButton)

                        Button("Erase all app data", systemImage: "trash", role: .destructive) {
                            showEraseDataConfirm = true
                        }
                        .accessibilityLabel("Erase all app data")
                        .accessibilityHint("Deletes workouts, history, Coach chats, readiness, photos, and other local data from this device")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .deleteAccountConfirmation(isPresented: $showDeleteAccountConfirm) {
                Task {
                    await authVM.deleteAccount(
                        dataManager: dataVM,
                        currentWorkout: currentVM,
                        entitlementStore: entitlementStore
                    )
                }
            }
            .sensoryFeedback(.warning, trigger: showDeleteAccountConfirm)
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
                Text("This permanently removes workouts, history, programs, Coach chats, readiness history, body metrics, and progress photos from this device. Workouts already written to Apple Health stay in Health until you delete them there. Export a backup first if you need one.")
            }
        }
    }

    /// Newest completed working set (skips warm-ups) or last cardio duration.
    private var resolvedLastLoadCaption: String? {
        if let lastLoadCaption { return lastLoadCaption }
        guard resolvesLastLoadFromEnvironment else { return nil }
        return PearlLastWorkingLoad.newestCompletedCaption(
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        )
    }
}

#Preview("More last load · strength") {
    Text("Last 185 lb × 8 reps")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding()
        .accessibilityIdentifier(FitLogA11yID.moreTab.lastLoad)
}

#Preview("More last load · dark cardio") {
    Text("Last 45:00")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding()
        .accessibilityIdentifier(FitLogA11yID.moreTab.lastLoad)
        .preferredColorScheme(.dark)
}
