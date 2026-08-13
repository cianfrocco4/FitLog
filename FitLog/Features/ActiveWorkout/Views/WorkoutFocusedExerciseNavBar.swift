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
                Text(positionLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                WorkoutFocusedExerciseNavAccessibility.currentExerciseAccessibilityLabel(
                    exerciseTitle: exerciseTitle,
                    positionLabel: positionLabel
                )
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
