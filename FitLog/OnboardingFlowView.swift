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
    case homeCardioQuickStart
}

struct OnboardingFlowView: View {
    @Binding var isPresented: Bool
    /// Called when onboarding ends (including Skip). Use to deep-link into Coach or New Workout.
    var onPostOnboarding: ((PostOnboardingRoutineAction) -> Void)?

    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var page = 0
    @State private var sessionsPerWeek = 3
    @State private var showPaywall = false

    private var lastPageIndex: Int { 4 }

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
                case 3:
                    premiumValuePage
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
                                page = min(lastPageIndex, page + 1)
                            }
                        }
                        .fontWeight(.semibold)
                    } else if page < lastPageIndex {
                        Button("Next") {
                            withAnimation {
                                page = min(lastPageIndex, page + 1)
                            }
                        }
                        .fontWeight(.semibold)
                    } else if page == lastPageIndex {
                        Button("Done") {
                            finishWithAction(.none)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggerFeature: .aiCoach, onDismiss: nil)
                .environment(entitlementStore)
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
            Text("Welcome to \(AppBrand.name)")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Track strength and cardio in one place — sets, intervals, readiness from Apple Health, and optional AI coaching.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Label("Log runs, rides, and intervals alongside your lifts", systemImage: "figure.run")
                .font(.subheadline)
                .foregroundStyle(FitlogPalette.chartSecondary)
                .padding(.top, 4)
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
                .accessibilityHint("Opens the coach to generate a training split")

                Button {
                    finishWithAction(.homeNewWorkoutTemplates)
                } label: {
                    Label("Use a quick-start template", systemImage: "rectangle.stack.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens Home with workout templates")

                Button {
                    finishWithAction(.homeNewWorkoutScratch)
                } label: {
                    Label("Start from scratch", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens Home to create a custom workout")

                Button {
                    finishWithAction(.homeCardioQuickStart)
                } label: {
                    Label("Build a cardio workout", systemImage: "figure.run")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(FitlogPalette.chartSecondary)
                .accessibilityHint("Opens the cardio workout builder with interval and steady templates")

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

    private var premiumValuePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Train smarter with Premium")
                .font(.title2.weight(.semibold))
            Text("Logging stays free forever. Premium unlocks private on-device coaching (Apple Intelligence), cloud AI when needed, readiness trends, and advanced analytics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("On-device AI adjust + cloud coach & program builder", systemImage: "sparkles")
            Label("Readiness trends (7–90 days) from Apple Health", systemImage: "heart.text.square.fill")
            Label("Advanced analytics, unlimited history, and export", systemImage: "chart.xyaxis.line")
            Text("Not medical advice — general fitness coaching tool only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("See Premium options") {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            Button("Continue with free plan") {
                withAnimation { page = lastPageIndex }
            }
            .font(.subheadline)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var wrapUpPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You’re set")
                .font(.title2.weight(.semibold))
            Label("Home shows today's plan, readiness, and your week.", systemImage: "house")
            Label("Plan is your calendar and training program.", systemImage: "calendar")
            Label("History shows the last 14 days free — unlock full history with Premium.", systemImage: "chart.bar")
            Label("Cardio templates cover steady state, intervals, and hybrid days.", systemImage: "figure.run")
                .foregroundStyle(FitlogPalette.chartSecondary)
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
