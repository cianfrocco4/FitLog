//
//  FitLogSimulatedUserUITests.swift
//  FitLogUITests
//
//  One XCUITest per catalog persona. Together these are N=5 sequential simulated users.
//  Run: scripts/run-simulated-users.sh
//

import XCTest

final class FitLogSimulatedUserUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNewFreeCreatesFirstWorkout() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "newFree")
        FitLogUITestSupport.tapTab("Home", in: app)

        XCTAssertTrue(
            app.staticTexts["No workouts yet"].waitForExistence(timeout: 10),
            "New free user should see the empty Home library"
        )

        let newWorkout = FitLogUITestSupport.control(app, identifier: "fitlog.newWorkout", label: "New workout")
        XCTAssertTrue(newWorkout.waitForExistence(timeout: 8), "Empty Home should offer New workout")
        newWorkout.tap()

        XCTAssertTrue(app.navigationBars["New workout"].waitForExistence(timeout: 10))
        let pushA = FitLogUITestSupport.control(app, identifier: "fitlog.quickStart.pushA", label: "Push A")
        if !pushA.waitForExistence(timeout: 4) {
            app.swipeLeft()
        }
        XCTAssertTrue(pushA.waitForExistence(timeout: 8), "Push A template should be visible")
        pushA.tap()

        XCTAssertTrue(app.buttons["Start workout"].waitForExistence(timeout: 15))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Push A"].waitForExistence(timeout: 10))

        FitLogUITestSupport.tapTab("Coach", in: app)
        XCTAssertTrue(
            app.staticTexts["Premium AI Coach"].waitForExistence(timeout: 8)
                || app.buttons["View Premium"].waitForExistence(timeout: 4),
            "New free user should see the Coach Premium gate"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "newFree-CoachGate", in: self)
    }

    @MainActor
    func testReturningFreeStartsRecentAndHistoryGate() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "returningFree")
        FitLogUITestSupport.tapTab("Home", in: app)

        XCTAssertTrue(
            app.staticTexts["Push A"].waitForExistence(timeout: 12),
            "Returning free user should already have Push A in the library"
        )
        XCTAssertFalse(app.staticTexts["No workouts yet"].exists)

        let start = FitLogUITestSupport.control(app, identifier: "fitlog.startWorkout", label: "Start workout")
        XCTAssertTrue(start.waitForExistence(timeout: 8), "Start workout FAB should exist")
        start.tap()

        let recentPush = app.buttons["Push A"]
        XCTAssertTrue(
            recentPush.waitForExistence(timeout: 10),
            "Start-workout sheet should list Push A under Recent"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "returningFree-StartSheet", in: self)
        app.buttons["Cancel"].tap()

        FitLogUITestSupport.tapTab("History", in: app)
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10))
        let filters = app.buttons["History filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 8), "History filters should be available")
        filters.tap()

        let lockedRange = app.descendants(matching: .any)["Last 30 days (Premium)"]
        XCTAssertTrue(
            lockedRange.waitForExistence(timeout: 8),
            "Free user should see Last 30 days as Premium-locked"
        )
        lockedRange.tap()
        XCTAssertTrue(
            app.buttons["Restore purchases"].waitForExistence(timeout: 10)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Premium'")).firstMatch.waitForExistence(timeout: 4),
            "Choosing a Premium history range should present the paywall"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "returningFree-HistoryPaywall", in: self)
    }

    @MainActor
    func testPremiumLifterSeesActiveSubscription() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "premiumLifter")
        FitLogUITestSupport.tapTab("Home", in: app)
        XCTAssertTrue(app.staticTexts["Push A"].waitForExistence(timeout: 12))

        FitLogUITestSupport.tapTab("History", in: app)
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 10))
        let filters = app.buttons["History filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 8))
        filters.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["Last 90 days"].waitForExistence(timeout: 8),
            "Premium lifter should see unlocked 90-day history"
        )
        app.swipeDown()

        FitLogUITestSupport.tapTab("More", in: app)
        let subscription = app.buttons["Subscription"]
        XCTAssertTrue(subscription.waitForExistence(timeout: 8))
        subscription.tap()
        XCTAssertTrue(
            app.staticTexts["Active"].waitForExistence(timeout: 10)
                || app.otherElements["Premium status, Active"].waitForExistence(timeout: 4),
            "Premium persona should show Active subscription status"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "premiumLifter-Subscription", in: self)
    }

    @MainActor
    func testCardioHobbyistSeesZone2Workout() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "cardioHobbyist")
        FitLogUITestSupport.tapTab("Home", in: app)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Zone 2'")).firstMatch.waitForExistence(timeout: 12),
            "Cardio hobbyist should have the Zone 2 template workout on Home"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "cardioHobbyist-Home", in: self)
    }

    @MainActor
    func testPlanFollowerSeesTodaysPushA() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "planFollower")
        FitLogUITestSupport.tapTab("Plan", in: app)
        XCTAssertTrue(
            app.staticTexts["Push A"].waitForExistence(timeout: 12)
                || app.buttons["Start workout"].waitForExistence(timeout: 6),
            "Plan follower should see today's assigned Push A (or Start workout) on Plan"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "planFollower-Plan", in: self)
    }
}
