//
//  OnboardingFlowView.swift
//  FitLog
//

import SwiftUI

enum PostOnboardingRoutineAction: Equatable {
    case none
    case homeProgramBuilder
    case homeNewWorkout
}

struct OnboardingFlowView: View {
    @Binding var isPresented: Bool
    /// Called when onboarding ends (including Skip). Use to deep-link into program or workout creation.
    var onPostOnboarding: ((PostOnboardingRoutineAction) -> Void)?

    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var page = 0
    @State private var sessionsPerWeek = 3

    private enum Page: Int {
        case welcome = 0
        case startChoice = 1
        case weeklyRhythm = 2
    }

    var body: some View {
        NavigationStack {
            Group {
                switch Page(rawValue: page) ?? .welcome {
                case .welcome:
                    welcomePage
                case .startChoice:
                    startChoicePage
                case .weeklyRhythm:
                    frequencyPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(page == Page.welcome.rawValue ? "" : "Get started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        finishWithAction(.none)
                    }
                    .accessibilityIdentifier("onboarding.skip")
                    .accessibilityHint("Skips setup and opens Home")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if page == Page.welcome.rawValue {
                        Button("Next") {
                            withAnimation { page = Page.startChoice.rawValue }
                        }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("onboarding.next")
                    } else if page == Page.weeklyRhythm.rawValue {
                        Button("Continue") {
                            finishWithAction(.homeProgramBuilder)
                        }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("onboarding.continuePlan")
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
                .accessibilityHidden(true)
            Text("Welcome to \(AppBrand.name)")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("A workout is a session you log. A program is the week that tells you what to train each day.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
        .accessibilityIdentifier("onboarding.welcome")
    }

    private var startChoicePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How do you want to start?")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Pick one path — you can always create the other later from Home.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                startPathCard(
                    title: "Plan my week",
                    subtitle: "Build a program so Home and Plan know what to train each day.",
                    systemImage: "calendar.badge.clock",
                    recommended: true,
                    identifier: "onboarding.planWeek"
                ) {
                    withAnimation { page = Page.weeklyRhythm.rawValue }
                }

                startPathCard(
                    title: "Log a workout today",
                    subtitle: "Create a session from a template or from scratch, then start logging.",
                    systemImage: "dumbbell.fill",
                    recommended: false,
                    identifier: "onboarding.logWorkout"
                ) {
                    finishWithAction(.homeNewWorkout)
                }

                Button("I’ll explore first") {
                    finishWithAction(.none)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .accessibilityIdentifier("onboarding.explore")
                .accessibilityHint("Opens Home with tips on creating a workout or program")
            }
            .padding()
        }
    }

    private var frequencyPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weekly rhythm")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("How many strength sessions do you want to aim for each week? You can change this anytime in Plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper(value: $sessionsPerWeek, in: 1...7) {
                Text("\(sessionsPerWeek) session\(sessionsPerWeek == 1 ? "" : "s") per week")
                    .font(.headline)
            }
            .padding(.vertical, 8)
            .accessibilityHint("Sets how many training days to aim for each week")
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("onboarding.frequency")
    }

    private func startPathCard(
        title: String,
        subtitle: String,
        systemImage: String,
        recommended: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if recommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(FitlogPalette.highlight.opacity(0.18)))
                                .foregroundStyle(FitlogPalette.highlight)
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FitlogPalette.subtleFill)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }

    private func finishWithAction(_ action: PostOnboardingRoutineAction) {
        dataVM.setTrainingSessionsPerWeek(sessionsPerWeek)
        userPreferences.markOnboardingComplete()
        onPostOnboarding?(action)
        isPresented = false
    }
}

#Preview("Welcome") {
    OnboardingFlowView(isPresented: .constant(true))
}
