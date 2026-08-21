//
//  HomeExpandLibraryNudgeTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite
struct HomeExpandLibraryNudgeTests {
    @Test func showsWhenLibraryHasExactlyOneWorkout() {
        #expect(HomeExpandLibraryNudge.shouldShow(libraryWorkoutCount: 1, isDismissed: false))
    }

    @Test func hidesWhenEmptyOrAlreadyExpanded() {
        #expect(!HomeExpandLibraryNudge.shouldShow(libraryWorkoutCount: 0, isDismissed: false))
        #expect(!HomeExpandLibraryNudge.shouldShow(libraryWorkoutCount: 2, isDismissed: false))
    }

    @Test func hidesWhenDismissed() {
        #expect(!HomeExpandLibraryNudge.shouldShow(libraryWorkoutCount: 1, isDismissed: true))
    }
}
