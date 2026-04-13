//
//  FitlogTabRouting.swift
//  FitLog
//
//  Lets deep-linked flows (e.g. AI split builder success) switch the root TabView.
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

/// In-memory Coach tab routing (e.g. Plan tab opens AI split builder with plan context).
extension Notification.Name {
    /// Home / onboarding asks Plan to present the program builder sheet.
    static let fitlogOpenProgramBuilder = Notification.Name("fitlogOpenProgramBuilder")
}

enum FitlogCoachDeepLink: Equatable {
    case idle
    /// Prefill is merged into the split builder “Additional notes” field.
    case openAISplitBuilder(prefill: String?)
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

    /// Switch Coach tab and optionally present the AI split builder with prefilled plan context.
    var fitlogCoachDeepLink: Binding<FitlogCoachDeepLink> {
        get { self[FitlogCoachDeepLinkKey.self] }
        set { self[FitlogCoachDeepLinkKey.self] = newValue }
    }

    /// Merged into AI split builder “Additional notes” once when non-nil (Plan / Coach deep link).
    var fitlogAISplitCoachPrefill: String? {
        get { self[FitlogAISplitCoachPrefillKey.self] }
        set { self[FitlogAISplitCoachPrefillKey.self] = newValue }
    }
}
