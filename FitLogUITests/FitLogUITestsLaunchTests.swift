//
//  FitLogUITestsLaunchTests.swift
//  FitLogUITests
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import XCTest

final class FitLogUITestsLaunchTests: XCTestCase {

    /// Avoid multiplying launch runs (light/dark, etc.) on Xcode Cloud — one configuration is enough.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        FitLogUITestSupport.configure(app)
        app.launch()

        _ = app.tabBars.firstMatch.waitForExistence(timeout: 30)
        FitLogUITestSupport.attachScreenshot(app, name: "Launch Screen", in: self)
    }
}
