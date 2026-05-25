//
//  MoreTabRootView.swift
//  FitLog
//
//  Secondary destinations (exercise library, data settings) to keep the tab bar at five items.
//

import SwiftUI

struct MoreTabRootView: View {
    @Environment(DataManager.self) var dataVM
    @EnvironmentObject var userPreferences: UserPreferences
    @EnvironmentObject var authVM: AuthViewModel

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
                    DataAndIntegrationsView()
                        .environmentObject(userPreferences)
                } label: {
                    Label("Data & Integrations", systemImage: "gearshape")
                }

                Section {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        authVM.logout()
                    }
                    .accessibilityHint("Signs out of your account")
                }
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
