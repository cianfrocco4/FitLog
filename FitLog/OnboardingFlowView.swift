//
//  OnboardingFlowView.swift
//  FitLog
//

import SwiftUI

struct OnboardingFlowView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var dataVM: DataManager
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var page = 0
    @State private var sessionsPerWeek = 3

    var body: some View {
        NavigationStack {
            Group {
                switch page {
                case 0:
                    welcomePage
                case 1:
                    frequencyPage
                default:
                    wrapUpPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(page == 0 ? "" : "Get started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { finishOnboarding() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if page < 2 {
                        Button("Next") {
                            withAnimation {
                                page = min(2, page + 1)
                            }
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Done") { finishOnboarding() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear {
            let current = dataVM.trainingProgram.sessionsPerWeek
            sessionsPerWeek = min(max(1, current), 7)
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Welcome to FitLog")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Track workouts, follow your plan, and see strength trends over time.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }

    private var frequencyPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weekly rhythm")
                .font(.title2.weight(.semibold))
            Text("How many strength sessions do you want to aim for each week? You can change this anytime in Plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper(value: $sessionsPerWeek, in: 1...7) {
                Text("\(sessionsPerWeek) session\(sessionsPerWeek == 1 ? "" : "s") per week")
                    .font(.headline)
            }
            .padding(.vertical, 8)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var wrapUpPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You’re set")
                .font(.title2.weight(.semibold))
            Label("Home shows today’s plan and your week.", systemImage: "house")
            Label("Plan is your calendar and training rotation.", systemImage: "calendar")
            Label("History holds every completed session.", systemImage: "chart.bar")
            Text("Tap Done to start logging, or use Skip anytime.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func finishOnboarding() {
        dataVM.setTrainingSessionsPerWeek(sessionsPerWeek)
        userPreferences.markOnboardingComplete()
        isPresented = false
    }
}
