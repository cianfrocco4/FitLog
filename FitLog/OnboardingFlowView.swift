//
//  OnboardingFlowView.swift
//  FitLog
//

import SwiftUI

enum PostOnboardingRoutineAction: Equatable {
    case none
    case coachAISplit
    case homeNewWorkoutTemplates
    case homeNewWorkoutScratch
}

struct OnboardingFlowView: View {
    @Binding var isPresented: Bool
    /// Called when onboarding ends (including Skip). Use to deep-link into Coach or New Workout.
    var onPostOnboarding: ((PostOnboardingRoutineAction) -> Void)?

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
                case 2:
                    routineChoicePage
                default:
                    wrapUpPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(page == 0 ? "" : "Get started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        finishWithAction(.none)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if page < 2 {
                        Button("Next") {
                            withAnimation {
                                page = min(3, page + 1)
                            }
                        }
                        .fontWeight(.semibold)
                    } else if page == 3 {
                        Button("Done") {
                            finishWithAction(.none)
                        }
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
            Text("How many strength sessions do you want to aim for each week? You can change this anytime under Plan → Program.")
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

    private var routineChoicePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Build your first routine")
                .font(.title2.weight(.semibold))
            Text("Pick one path — you can always change things later in Home or Plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    finishWithAction(.coachAISplit)
                } label: {
                    Label("Build a split", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    finishWithAction(.homeNewWorkoutTemplates)
                } label: {
                    Label("Use a quick-start template", systemImage: "rectangle.stack.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    finishWithAction(.homeNewWorkoutScratch)
                } label: {
                    Label("Start from scratch", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button("Skip for now") {
                    withAnimation {
                        page = 3
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
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
            Label("Plan is your calendar and training program.", systemImage: "calendar")
            Label("History holds every completed session.", systemImage: "chart.bar")
            Text("Tap Done to start logging, or use Skip anytime.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func finishWithAction(_ action: PostOnboardingRoutineAction) {
        dataVM.setTrainingSessionsPerWeek(sessionsPerWeek)
        userPreferences.markOnboardingComplete()
        isPresented = false
        onPostOnboarding?(action)
    }
}
