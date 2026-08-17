//
//  FitLogUserJourneyUITests.swift
//  FitLogUITests
//
//  Scripted “real user” smoke: tabs, create-from-template, Coach Premium gate.
//

import XCTest

final class FitLogUserJourneyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabBarNavigationSmoke() throws {
        let app = FitLogUITestSupport.launchConfiguredApp()

        for tab in ["Home", "Plan", "History", "Coach", "More"] {
            FitLogUITestSupport.tapTab(tab, in: app)
            XCTAssertTrue(
                app.tabBars.buttons[tab].isSelected || app.tabBars.buttons[tab].exists,
                "\(tab) tab should remain available after tap"
            )
            FitLogUITestSupport.attachScreenshot(app, name: "Tab-\(tab)", in: self)
        }

        FitLogUITestSupport.tapTab("Home", in: app)
        XCTAssertTrue(
            app.staticTexts["No workouts yet"].waitForExistence(timeout: 8)
                || FitLogUITestSupport.control(app, identifier: "fitlog.startWorkout", label: "Start workout")
                    .waitForExistence(timeout: 4),
            "Home should show empty-state copy or the Start workout FAB."
        )
    }

    @MainActor
    func testCreatePushAWorkoutFromHome() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "newFree")
        FitLogUITestSupport.tapTab("Home", in: app)

        let newWorkout = FitLogUITestSupport.control(app, identifier: "fitlog.newWorkout", label: "New workout")
        if newWorkout.waitForExistence(timeout: 8) {
            newWorkout.tap()
        } else {
            let start = FitLogUITestSupport.control(app, identifier: "fitlog.startWorkout", label: "Start workout")
            XCTAssertTrue(start.waitForExistence(timeout: 8), "Start workout FAB should exist when empty-state New workout is missing")
            start.tap()
            let sheetNew = FitLogUITestSupport.control(app, identifier: "fitlog.newWorkout", label: "New workout")
            XCTAssertTrue(sheetNew.waitForExistence(timeout: 8), "Start-workout sheet should offer New workout")
            sheetNew.tap()
        }

        XCTAssertTrue(
            app.navigationBars["New workout"].waitForExistence(timeout: 10),
            "New workout sheet should open"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "NewWorkoutSheet", in: self)

        let pushA = FitLogUITestSupport.control(app, identifier: "fitlog.quickStart.pushA", label: "Push A")
        if !pushA.waitForExistence(timeout: 4) {
            app.swipeLeft()
        }
        XCTAssertTrue(pushA.waitForExistence(timeout: 8), "Push A quick-start template should be visible")
        pushA.tap()

        let startWorkout = app.buttons["Start workout"]
        XCTAssertTrue(
            startWorkout.waitForExistence(timeout: 15),
            "Creating Push A should land on the workout plan with Start workout enabled"
        )
        XCTAssertTrue(startWorkout.isEnabled, "Push A should include starter exercises so Start is enabled")
        FitLogUITestSupport.attachScreenshot(app, name: "PushA-Plan", in: self)

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 6), "Creation flow should offer Done to return Home")
        done.tap()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Done should dismiss the new-workout sheet back to Home"
        )
        XCTAssertTrue(
            app.staticTexts["Push A"].waitForExistence(timeout: 10),
            "Home library should list the Push A workout that was just created"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "Home-AfterPushA", in: self)
    }

    @MainActor
    func testCoachTabShowsComposerAndPremiumGate() throws {
        let app = FitLogUITestSupport.launchConfiguredApp(persona: "newFree")
        FitLogUITestSupport.tapTab("Coach", in: app)

        XCTAssertTrue(
            app.navigationBars["Coach"].waitForExistence(timeout: 10),
            "Coach tab should show the Coach navigation title"
        )

        XCTAssertTrue(
            app.staticTexts["Premium AI Coach"].waitForExistence(timeout: 8)
                || app.buttons["View Premium"].waitForExistence(timeout: 4),
            "Free persona should see the Coach Premium banner"
        )

        let message = app.textFields["Message"]
        let messageTextView = app.textViews["Message"]
        XCTAssertTrue(
            message.waitForExistence(timeout: 8) || messageTextView.waitForExistence(timeout: 2),
            "Coach composer should be visible for VoiceOver (Message)."
        )

        let send = app.buttons["Send"]
        XCTAssertTrue(send.waitForExistence(timeout: 8), "Send control should exist")
        XCTAssertFalse(
            send.isEnabled,
            "Free UI-test user should not send Coach messages (empty draft and/or Premium gate)."
        )
        FitLogUITestSupport.attachScreenshot(app, name: "Coach-FreeComposer", in: self)
    }

    @MainActor
    func testHistoryAndPlanTabsLoad() throws {
        let app = FitLogUITestSupport.launchConfiguredApp()

        FitLogUITestSupport.tapTab("Plan", in: app)
        XCTAssertTrue(
            app.tabBars.buttons["Plan"].waitForExistence(timeout: 8),
            "Plan tab should remain after selection"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "Plan", in: self)

        FitLogUITestSupport.tapTab("History", in: app)
        XCTAssertTrue(
            app.navigationBars["History"].waitForExistence(timeout: 10),
            "History should use a History navigation title"
        )
        XCTAssertTrue(
            app.buttons["Overview"].waitForExistence(timeout: 8)
                || app.segmentedControls.firstMatch.waitForExistence(timeout: 4),
            "History should show Overview/Sessions/Explore sections"
        )
        FitLogUITestSupport.attachScreenshot(app, name: "History", in: self)
    }
}
