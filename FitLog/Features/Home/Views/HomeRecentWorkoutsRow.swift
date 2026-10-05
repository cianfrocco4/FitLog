//
//  HomeRecentWorkoutsRow.swift
//  FitLog
//
//  Horizontal quick-start row for recently completed workouts.
//

import SwiftUI

struct HomeRecentWorkoutsRow: View {
    let workouts: [Workout]
    let lastCompletedDates: [UUID: Date]
    let onStart: (Workout) -> Void
    /// Optional last-load captions keyed by library workout id.
    var lastLoadCaptionByWorkoutId: [UUID: String] = [:]
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Quick start", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(workouts) { workout in
                        Button {
                            onStart(workout)
                        } label: {
                            HomeRecentWorkoutChip(
                                workout: workout,
                                lastDone: lastCompletedDates[workout.id],
                                lastLoadCaption: lastLoadCaptionByWorkoutId[workout.id],
                                resolvesLastLoadFromEnvironment: resolvesLastLoadFromEnvironment
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onStart(workout)
                            } label: {
                                Label("Start workout", systemImage: "play.fill")
                            }
                        }
                        .accessibilityHint("Starts this workout immediately")
                    }
                }
            }
        }
        .homeCardTier(.secondary)
    }
}

private struct HomeRecentWorkoutChip: View {
    let workout: Workout
    let lastDone: Date?
    var lastLoadCaption: String? = nil
    var resolvesLastLoadFromEnvironment: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: workout.workoutKind.homeSystemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(workout.workoutKind.homeAccentColor)
                Text(workout.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Text(HomeWorkoutFormatting.lastDoneLabel(for: lastDone))
                .font(.caption2)
                .foregroundStyle(.secondary)
            lastLoadCaptionView
            Text("\(workout.exercises.count) exercises")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 148, alignment: .leading)
        .padding(12)
        .background(workout.workoutKind.homeAccentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(workout.workoutKind.homeAccentColor)
                .frame(width: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chipAccessibilityLabel)
    }

    @ViewBuilder
    private var lastLoadCaptionView: some View {
        if let lastLoadCaption, !lastLoadCaption.isEmpty {
            lastLoadLine(lastLoadCaption)
        } else if resolvesLastLoadFromEnvironment {
            HomeRecentWorkoutLastLoadCaption(workout: workout)
        }
    }

    private func lastLoadLine(_ caption: String) -> some View {
        Text(caption)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(FitLogA11yID.homeRecentWorkouts.lastLoad)
            .accessibilityLabel(caption)
            .accessibilityHint("Last working set or last cardio duration from a completed session")
            .accessibilityAddTraits(.isStaticText)
    }

    private var chipAccessibilityLabel: String {
        var parts = [workout.name, HomeWorkoutFormatting.lastDoneLabel(for: lastDone)]
        if let lastLoadCaption, !lastLoadCaption.isEmpty {
            parts.append(lastLoadCaption)
        }
        return parts.joined(separator: ", ")
    }
}

private struct HomeRecentWorkoutLastLoadCaption: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences
    let workout: Workout

    var body: some View {
        if let lastLoad = SequoiaLastWorkingLoad.caption(
            for: workout,
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        ) {
            Text(lastLoad)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(FitLogA11yID.homeRecentWorkouts.lastLoad)
                .accessibilityLabel(lastLoad)
                .accessibilityHint("Last working set or last cardio duration from a completed session")
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

#if DEBUG
#Preview("Recent row") {
    HomeRecentWorkoutsRow(
        workouts: [
            Workout(id: UUID(), name: "Push Day", exercises: [], workoutKind: .strength),
            Workout(id: UUID(), name: "Easy Run", exercises: [], workoutKind: .cardio)
        ],
        lastCompletedDates: [:],
        onStart: { _ in },
        lastLoadCaptionByWorkoutId: [:],
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("Recent row last load") {
    let pushId = UUID()
    let runId = UUID()
    HomeRecentWorkoutsRow(
        workouts: [
            Workout(id: pushId, name: "Push Day", exercises: [], workoutKind: .strength),
            Workout(id: runId, name: "Easy Run", exercises: [], workoutKind: .cardio)
        ],
        lastCompletedDates: [pushId: Date().addingTimeInterval(-86_400)],
        onStart: { _ in },
        lastLoadCaptionByWorkoutId: [
            pushId: "Last 185 lb × 8 reps",
            runId: "Last 45:00"
        ],
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
}

#Preview("Recent row last load dark") {
    let pushId = UUID()
    HomeRecentWorkoutsRow(
        workouts: [
            Workout(id: pushId, name: "Push Day", exercises: [], workoutKind: .strength)
        ],
        lastCompletedDates: [pushId: Date().addingTimeInterval(-86_400)],
        onStart: { _ in },
        lastLoadCaptionByWorkoutId: [pushId: "Last 185 lb × 8 reps"],
        resolvesLastLoadFromEnvironment: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
#endif
