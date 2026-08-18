//
//  FitLogUITests.swift
//  FitLogUITests
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import XCTest

final class FitLogUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        FitLogUITestSupport.configure(app)
        app.launch()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "Main tab bar should appear after launch (UI test login bypass)."
        )
    }

    @MainActor
    func testDeleteAccountFlowReturnsToSignIn() throws {
        let app = XCUIApplication()
        FitLogUITestSupport.configure(app)
        app.launch()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "Main tab bar should appear after launch (UI test login bypass)."
        )

        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "More tab should exist")
        moreTab.tap()

        let deleteAccount = app.buttons["Delete Account"]
        XCTAssertTrue(
            deleteAccount.waitForExistence(timeout: 10),
            "Guideline 5.1.1(v): signed-in users must see Delete Account on More."
        )
        deleteAccount.tap()

        let confirm = app.alerts["Delete Account?"].buttons["Delete Account"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8), "Delete Account confirmation must appear")
        confirm.tap()

        XCTAssertTrue(
            app.buttons["Continue without signing in"].waitForExistence(timeout: 10),
            "Account deletion must return to the sign-in screen."
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    @MainActor
    func testFirstRunOnboardingTwoPathAndHomeHero() throws {
        let app = XCUIApplication()
        FitLogUITestSupport.configure(app, skipOnboarding: false, forceOnboarding: true)
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)["onboarding.welcome"].waitForExistence(timeout: 20)
                || app.staticTexts["Welcome to Workout Log AI"].waitForExistence(timeout: 20),
            "Onboarding welcome should appear for a new user."
        )

        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8), "Welcome Next should exist")
        next.tap()

        XCTAssertTrue(
            app.buttons["onboarding.planWeek"].waitForExistence(timeout: 8),
            "Plan my week should be a first-run path."
        )
        XCTAssertTrue(
            app.buttons["onboarding.logWorkout"].exists,
            "Log a workout today should be a first-run path."
        )

        let explore = app.buttons["onboarding.explore"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5), "I'll explore first should exist")
        explore.tap()

        let skipTour = app.buttons["spotlight.skip"]
        if skipTour.waitForExistence(timeout: 6) {
            skipTour.tap()
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["firstRun.hero"].waitForExistence(timeout: 12)
                || app.staticTexts["Create something to train"].waitForExistence(timeout: 12),
            "First-run Home hero should explain how to create a workout or program."
        )
        XCTAssertTrue(app.buttons["firstRun.newWorkout"].exists)
        XCTAssertTrue(app.buttons["firstRun.buildProgram"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
            || ProcessInfo.processInfo.environment["XCODE_CLOUD"] == "1"
        try XCTSkipIf(isCI, "Launch performance metrics are unreliable on Xcode Cloud")

        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                FitLogUITestSupport.configure(app)
                app.launch()
            }
        }
    }
}
