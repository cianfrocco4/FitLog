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
    var lastDurations: [UUID: Int] = [:]
    let onStart: (Workout) -> Void

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
                                lastDurationSeconds: lastDurations[workout.id]
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
    var lastDurationSeconds: Int? = nil

    private var lastDoneText: String {
        HomeWorkoutFormatting.lastDoneWithDurationLabel(
            date: lastDone,
            durationSeconds: lastDurationSeconds
        )
    }

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
            Text(lastDoneText)
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        .accessibilityLabel("\(workout.name), \(lastDoneText)")
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
        onStart: { _ in }
    )
    .padding()
}
#endif
