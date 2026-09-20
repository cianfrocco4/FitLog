//
//  WorkoutFocusedExerciseNavBar.swift
//  FitLog
//
//  Prev / next controls for focused single-exercise logging.
//

import SwiftUI

struct WorkoutFocusedExerciseNavBar: View {
    let exerciseTitle: String
    let positionLabel: String
    var lastLoadCaption: String? = nil
    let canGoPrevious: Bool
    let canGoNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPrevious) {
                Label("Previous", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canGoPrevious ? .primary : .tertiary)
            .disabled(!canGoPrevious)
            .accessibilityLabel("Previous exercise")
            .accessibilityHint(WorkoutFocusedExerciseNavAccessibility.previousHint(canGoPrevious: canGoPrevious))

            VStack(spacing: 2) {
                Text(exerciseTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let lastLoadCaption, !lastLoadCaption.isEmpty {
                    Text(lastLoadCaption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(positionLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                WorkoutFocusedExerciseNavAccessibility.currentExerciseAccessibilityLabel(
                    exerciseTitle: exerciseTitle,
                    positionLabel: positionLabel,
                    lastLoadCaption: lastLoadCaption
                )
            )
            .accessibilityIdentifier(
                lastLoadCaption?.isEmpty == false ? FitLogA11yID.focusedExerciseNav.lastLoad : ""
            )

            Button(action: onNext) {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canGoNext ? .primary : .tertiary)
            .disabled(!canGoNext)
            .accessibilityLabel("Next exercise")
            .accessibilityHint(WorkoutFocusedExerciseNavAccessibility.nextHint(canGoNext: canGoNext))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview("With last load") {
    WorkoutFocusedExerciseNavBar(
        exerciseTitle: "Barbell Bench Press",
        positionLabel: "Exercise 2 of 5",
        lastLoadCaption: "Last 185 lb × 8 reps",
        canGoPrevious: true,
        canGoNext: true,
        onPrevious: {},
        onNext: {}
    )
}

#Preview("No history") {
    WorkoutFocusedExerciseNavBar(
        exerciseTitle: "Goblet Squat",
        positionLabel: "Exercise 1 of 4",
        canGoPrevious: false,
        canGoNext: true,
        onPrevious: {},
        onNext: {}
    )
}

#Preview("Dark last load") {
    WorkoutFocusedExerciseNavBar(
        exerciseTitle: "Treadmill Run",
        positionLabel: "Exercise 4 of 4",
        lastLoadCaption: "Last 45:00",
        canGoPrevious: true,
        canGoNext: false,
        onPrevious: {},
        onNext: {}
    )
    .preferredColorScheme(.dark)
}
