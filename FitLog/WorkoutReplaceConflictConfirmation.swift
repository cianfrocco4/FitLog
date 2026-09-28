//
//  WorkoutReplaceConflictConfirmation.swift
//  FitLog
//

import SwiftUI

struct WorkoutReplaceConflictConfirmation: ViewModifier {
    let currentVM: CurrentWorkoutSessionViewModel
    @Binding var pending: PendingWorkoutReplace?
    /// Called after the user confirms and the new workout has started (e.g. dismiss a sheet).
    var onAfterReplace: (() -> Void)?
    /// Called when the user cancels the dialog (not called after Continue).
    var onCancelReplace: (() -> Void)?

    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Active workout",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if !$0 { pending = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) {
                    if let p = pending {
                        if let resumed = p.resumedSession {
                            currentVM.stopThenApplyResumedSession(resumed)
                        } else {
                            currentVM.stopThenStartWorkout(p.workout, sessionPlanOrigin: p.sessionPlanOrigin)
                        }
                    }
                    pending = nil
                    onAfterReplace?()
                }
                Button("Cancel", role: .cancel) {
                    pending = nil
                    onCancelReplace?()
                }
            } message: {
                if let p = pending {
                    Text(replaceMessage(for: p))
                        .accessibilityIdentifier(FitLogA11yID.workoutReplace.lastLoad)
                }
            }
    }

    private func replaceMessage(for pending: PendingWorkoutReplace) -> String {
        let activeName = currentVM.currentSession?.workout.name ?? "your current workout"
        let suffix = pending.resumedSession != nil
            ? " Your logged sets from that earlier session will be restored."
            : ""
        var message = "“\(activeName)” is still in progress. Starting “\(pending.workout.name)” will complete that session and save it to your history.\(suffix)"
        if let lastLoad = AshLastWorkingLoad.caption(
            for: pending.workout,
            from: dataVM.completedSessions,
            displayUnit: userPreferences.weightDisplayUnit
        ) {
            message += " \(lastLoad)."
        }
        return message
    }
}

extension View {
    func workoutReplaceConflictConfirmation(
        currentVM: CurrentWorkoutSessionViewModel,
        pending: Binding<PendingWorkoutReplace?>,
        onAfterReplace: (() -> Void)? = nil,
        onCancelReplace: (() -> Void)? = nil
    ) -> some View {
        modifier(WorkoutReplaceConflictConfirmation(
            currentVM: currentVM,
            pending: pending,
            onAfterReplace: onAfterReplace,
            onCancelReplace: onCancelReplace
        ))
    }
}
