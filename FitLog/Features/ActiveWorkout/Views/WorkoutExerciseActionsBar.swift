//
//  WorkoutExerciseActionsBar.swift
//  FitLog
//
//  Always-visible actions for the focused exercise in the active workout sheet.
//

import SwiftUI

/// Swap is the most common mid-workout action, so it sits in the header with everything
/// rarer behind overflow, instead of being buried in a collapsed group.
struct WorkoutExerciseActionsBar: View {
    let exerciseName: String
    let canRepeatLastSet: Bool
    let supersetToggleTitle: String
    let showsEndSupersetRound: Bool
    /// Present only for template slots, where the plan itself can be changed.
    let canChangePlanSlot: Bool
    let onSwap: () -> Void
    let onRepeatLastSet: () -> Void
    let onFocusExercise: () -> Void
    let onToggleSuperset: () -> Void
    let onEndSupersetRound: () -> Void
    let onMarkCompleted: () -> Void
    let onChangePlanSlot: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSwap) {
                Label("Swap", systemImage: "arrow.left.arrow.right")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap \(exerciseName) for this session")
            .accessibilityHint("Replaces this exercise for today without changing your plan")

            Button(action: onRepeatLastSet) {
                Label("Repeat last", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canRepeatLastSet)
            .opacity(canRepeatLastSet ? 1 : 0.5)
            .accessibilityLabel("Repeat last set of \(exerciseName)")
            .accessibilityHint(
                canRepeatLastSet
                    ? "Logs another set with the same weight and reps"
                    : "Log a set first to repeat it"
            )

            Spacer(minLength: 4)

            Menu {
                Button("Focus this exercise", systemImage: "scope", action: onFocusExercise)
                Button(supersetToggleTitle, systemImage: "bolt.horizontal", action: onToggleSuperset)
                if showsEndSupersetRound {
                    Button("End superset round", systemImage: "bolt.horizontal.circle", action: onEndSupersetRound)
                }
                Divider()
                Button("Mark completed", systemImage: "checkmark.circle", action: onMarkCompleted)
                if canChangePlanSlot {
                    // Distinct from Swap: this edits the plan slot, not just today's session.
                    Button("Change the plan slot", systemImage: "calendar.badge.clock", action: onChangePlanSlot)
                }
                Button("Remove from workout", systemImage: "trash", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More actions for \(exerciseName)")
        }
    }
}

#Preview("Template slot row") {
    WorkoutExerciseActionsBar(
        exerciseName: "T-Bar Row",
        canRepeatLastSet: true,
        supersetToggleTitle: "Add to superset round",
        showsEndSupersetRound: false,
        canChangePlanSlot: true,
        onSwap: {},
        onRepeatLastSet: {},
        onFocusExercise: {},
        onToggleSuperset: {},
        onEndSupersetRound: {},
        onMarkCompleted: {},
        onChangePlanSlot: {},
        onRemove: {}
    )
    .padding()
}

#Preview("Mid-round, no sets yet — dark") {
    WorkoutExerciseActionsBar(
        exerciseName: "Lat Pulldown",
        canRepeatLastSet: false,
        supersetToggleTitle: "Remove from superset round",
        showsEndSupersetRound: true,
        canChangePlanSlot: false,
        onSwap: {},
        onRepeatLastSet: {},
        onFocusExercise: {},
        onToggleSuperset: {},
        onEndSupersetRound: {},
        onMarkCompleted: {},
        onChangePlanSlot: {},
        onRemove: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
