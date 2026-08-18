//
//  FitlogTabRouting.swift
//  FitLog
//
//  Lets deep-linked flows (e.g. split builder success) switch the root TabView.
//  No persisted schema — in-memory routing only.
//

import SwiftUI

enum FitlogRootTab: Int, Hashable {
    case home = 0
    case plan = 1
    case history = 2
    case coach = 3
    case more = 4
}

/// In-memory Coach tab routing (e.g. Plan tab opens the split builder with plan context).
extension Notification.Name {
    /// Home / onboarding asks Plan to present the program builder sheet.
    static let fitlogOpenProgramBuilder = Notification.Name("fitlogOpenProgramBuilder")
    /// Home / onboarding presents the dynamic program builder (`SplitBuilderView`) on Home.
    static let fitlogPresentSplitBuilder = Notification.Name("fitlogPresentSplitBuilder")
    /// Posted when a first-run sheet dismisses so the tab shell can start the spotlight tour.
    static let fitlogStartPendingSpotlight = Notification.Name("fitlogStartPendingSpotlight")
    /// Posted when the calendar “today” moves into a new dynamic program block (multi-block programs).
    static let fitlogDynamicProgramBlockChanged = Notification.Name("fitlogDynamicProgramBlockChanged")
    /// Posted after a workout session is saved to history (readiness/widget refresh).
    static let fitlogWorkoutCompleted = Notification.Name("fitlogWorkoutCompleted")
    /// Opens History → Sessions and pushes session detail. `object` is the session `UUID`.
    static let fitlogOpenHistorySession = Notification.Name("fitlogOpenHistorySession")
}

enum FitLogDeepLink: Equatable {
    /// Opens Home and presents new-workout / current-workout pull-up.
    case quickLog
    /// Opens the app to Home without starting a log flow (e.g. empty readiness widget).
    case open

    init?(url: URL) {
        guard url.scheme?.lowercased() == "fitlog" else { return nil }
        switch url.host?.lowercased() {
        case "quick-log":
            self = .quickLog
        case "open", "home":
            self = .open
        default:
            return nil
        }
    }
}

enum FitlogCoachDeepLink: Equatable {
    case idle
    /// Opens the program builder wizard; prefill is merged into “Additional notes” on the generation request.
    case openDynamicProgramBuilder(prefill: String?)
}

private struct FitlogRootTabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<FitlogRootTab>? = nil
}

private struct FitlogCoachDeepLinkKey: EnvironmentKey {
    static var defaultValue: Binding<FitlogCoachDeepLink> { .constant(.idle) }
}

private struct FitlogAISplitCoachPrefillKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// When non-nil, child views can switch tabs via the binding (e.g. open Plan after applying a split).
    var fitlogRootTabSelection: Binding<FitlogRootTab>? {
        get { self[FitlogRootTabSelectionKey.self] }
        set { self[FitlogRootTabSelectionKey.self] = newValue }
    }

    /// Switch Coach tab and optionally present the program builder with prefilled plan context.
    var fitlogCoachDeepLink: Binding<FitlogCoachDeepLink> {
        get { self[FitlogCoachDeepLinkKey.self] }
        set { self[FitlogCoachDeepLinkKey.self] = newValue }
    }

    /// Merged into the program builder’s “Additional notes” once when non-nil (Plan / Coach deep link).
    var fitlogAISplitCoachPrefill: String? {
        get { self[FitlogAISplitCoachPrefillKey.self] }
        set { self[FitlogAISplitCoachPrefillKey.self] = newValue }
    }
}
