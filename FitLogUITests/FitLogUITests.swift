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
