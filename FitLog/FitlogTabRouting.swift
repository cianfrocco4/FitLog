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

private struct FitlogRootTabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<FitlogRootTab>? = nil
}

extension EnvironmentValues {
    /// When non-nil, child views can switch tabs via the binding (e.g. open Plan after applying a split).
    var fitlogRootTabSelection: Binding<FitlogRootTab>? {
        get { self[FitlogRootTabSelectionKey.self] }
        set { self[FitlogRootTabSelectionKey.self] = newValue }
    }
}
