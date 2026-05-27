//
//  WorkoutBarPassthroughOverlay.swift
//  FitLog
//
//  Shared workout chrome constants and environment keys for the active workout strip.
//

import SwiftUI

/// Sheet detents for the active workout pull-up. Expanded height leaves the tab bar exposed.
enum FitlogWorkoutSheetDetent {
    static let collapsed = PresentationDetent.fraction(0.14)
    static let medium = PresentationDetent.fraction(0.42)
    static let expanded = PresentationDetent.fraction(0.85)

    static let all: Set<PresentationDetent> = [collapsed, medium, expanded]
    static let defaultOpen = medium
}

private enum OpenCurrentWorkoutSheetKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private enum OpenPullUpToExerciseLogIndexKey: EnvironmentKey {
    static let defaultValue: ((Int) -> Void)? = nil
}

private enum IsCurrentWorkoutSheetPresentedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Opens the full current-workout sheet (same as tapping the bottom bar).
    var openCurrentWorkoutSheet: (() -> Void)? {
        get { self[OpenCurrentWorkoutSheetKey.self] }
        set { self[OpenCurrentWorkoutSheetKey.self] = newValue }
    }

    /// Opens the pull-up sheet focused on the given `exerciseLogs` index and presents log set when appropriate.
    var openPullUpToExerciseLogIndex: ((Int) -> Void)? {
        get { self[OpenPullUpToExerciseLogIndexKey.self] }
        set { self[OpenPullUpToExerciseLogIndexKey.self] = newValue }
    }

    /// True while the root workout pull-up sheet is presented (hide duplicate collapsed bar).
    var isCurrentWorkoutSheetPresented: Bool {
        get { self[IsCurrentWorkoutSheetPresentedKey.self] }
        set { self[IsCurrentWorkoutSheetPresentedKey.self] = newValue }
    }
}

extension View {
    func workoutCollapsedBarInset() -> some View {
        modifier(WorkoutCollapsedBarInsetModifier())
    }
}

private struct WorkoutCollapsedBarInsetModifier: ViewModifier {
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @Environment(\.isCurrentWorkoutSheetPresented) private var isWorkoutSheetPresented

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if currentVM.isInProgress, !isWorkoutSheetPresented {
                CurrentWorkoutCollapsedBar()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
    }
}
