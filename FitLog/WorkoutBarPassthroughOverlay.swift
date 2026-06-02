//
//  WorkoutBarPassthroughOverlay.swift
//  FitLog
//
//  Shared workout chrome constants and environment keys for the active workout strip.
//

import SwiftUI

/// Sheet detents for the active workout pull-up.
enum FitlogWorkoutSheetDetent {
    static let collapsed = PresentationDetent.fraction(0.14)
    static let medium = PresentationDetent.fraction(0.42)
    /// Full-height logging surface (tab bar remains visible under the sheet).
    static let expanded = PresentationDetent.fraction(0.97)

    static let all: Set<PresentationDetent> = [collapsed, medium, expanded]
    static let defaultOpen = expanded
}

/// Extra padding below the measured collapsed bar for scroll clearance.
enum FitlogWorkoutChromeMetrics {
    static let collapsedBarScrollPadding: CGFloat = 16
    /// Medium detent fraction (must match `FitlogWorkoutSheetDetent.medium`).
    static let mediumDetentFraction: CGFloat = 0.42
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

private enum FitlogWorkoutSheetDetentKey: EnvironmentKey {
    static let defaultValue: PresentationDetent = FitlogWorkoutSheetDetent.expanded
}

extension EnvironmentValues {
    var fitlogWorkoutSheetDetent: PresentationDetent {
        get { self[FitlogWorkoutSheetDetentKey.self] }
        set { self[FitlogWorkoutSheetDetentKey.self] = newValue }
    }
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

    /// Extra bottom padding when an active workout bar may cover list footers (plan view, pull-up list).
    func workoutBottomScrollClearance() -> some View {
        modifier(WorkoutBottomScrollClearanceModifier())
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

private struct WorkoutBottomScrollClearanceModifier: ViewModifier {
    func body(content: Content) -> some View {
        WorkoutBottomScrollClearanceHost { content }
    }
}

private struct WorkoutScrollHostHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct WorkoutBottomScrollClearanceHost<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @Environment(\.isCurrentWorkoutSheetPresented) private var isWorkoutSheetPresented
    @Environment(\.fitlogWorkoutSheetDetent) private var workoutSheetDetent
    @Environment(\.workoutChromeMetrics) private var chromeMetrics
    @State private var hostHeight: CGFloat = 0

    private var usesCollapsedBarClearance: Bool {
        currentVM.isInProgress && !isWorkoutSheetPresented
    }

    private var usesMediumDetentClearance: Bool {
        currentVM.isInProgress
            && isWorkoutSheetPresented
            && workoutSheetDetent == FitlogWorkoutSheetDetent.medium
    }

    private var obscuredHeight: CGFloat {
        if usesCollapsedBarClearance {
            return chromeMetrics.collapsedBarHeight + FitlogWorkoutChromeMetrics.collapsedBarScrollPadding
        }
        if usesMediumDetentClearance, hostHeight > 0 {
            return hostHeight * FitlogWorkoutChromeMetrics.mediumDetentFraction
        }
        return 0
    }

    var body: some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: WorkoutScrollHostHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(WorkoutScrollHostHeightKey.self) { hostHeight = $0 }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if obscuredHeight > 0 {
                    Color.clear
                        .frame(height: obscuredHeight)
                        .allowsHitTesting(false)
                }
            }
    }
}
