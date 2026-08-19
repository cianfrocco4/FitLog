//
//  FirstRunHomeHeroView.swift
//  FitLog
//
//  Empty Home for brand-new users: one place to create a workout or a weekly program.
//

import SwiftUI

struct FirstRunHomeHeroView: View {
    var onNewWorkout: () -> Void
    var onFromTemplate: () -> Void
    var onBuildProgram: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Create something to train")
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text("A workout is a session you log. A program fills your week so Home knows what to train today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            workoutCard
            programCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("firstRun.hero")
        .spotlightAnchor(.firstRunHero)
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log a workout")
                        .font(.headline)
                    Text("Pick a template or start from scratch, then add exercises.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button("New workout") { onNewWorkout() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("firstRun.newWorkout")
                    .accessibilityHint("Opens a form to create a strength or cardio workout")

                Button("From template") { onFromTemplate() }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("firstRun.fromTemplate")
                    .accessibilityHint("Opens quick-start workout templates")
            }
        }
        .homeCardTier(.primary)
        .accessibilityElement(children: .contain)
    }

    private var programCard: some View {
        Button(action: onBuildProgram) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Color.accentColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("Build a weekly program")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(FitlogPalette.highlight.opacity(0.18)))
                                .foregroundStyle(FitlogPalette.highlight)
                        }
                        Text("Choose a split and we’ll schedule your training days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                Text("Get started")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .homeCardTier(.tertiary)
        .accessibilityIdentifier("firstRun.buildProgram")
        .accessibilityLabel("Build a weekly program")
        .accessibilityHint("Opens the program builder to schedule your week")
    }
}

#Preview("Light") {
    FirstRunHomeHeroView(onNewWorkout: {}, onFromTemplate: {}, onBuildProgram: {})
        .padding()
}

#Preview("Dark") {
    FirstRunHomeHeroView(onNewWorkout: {}, onFromTemplate: {}, onBuildProgram: {})
        .padding()
        .preferredColorScheme(.dark)
}
