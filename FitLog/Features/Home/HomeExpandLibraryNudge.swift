//
//  HomeExpandLibraryNudge.swift
//  FitLog
//
//  Visibility for the Home “add a second workout” card after the first template.
//

import Foundation

enum HomeExpandLibraryNudge {
    /// Show after the library has exactly one saved workout (typical first template).
    static func shouldShow(libraryWorkoutCount: Int, isDismissed: Bool) -> Bool {
        libraryWorkoutCount == 1 && !isDismissed
    }
}
