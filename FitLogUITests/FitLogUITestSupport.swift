//
//  FitLogUITestSupport.swift
//  FitLogUITests
//
//  Shared launch configuration and query helpers for simulator UI tests.
//

import XCTest

enum FitLogUITestSupport {

    /// Call before `launch()`. Skips Apple credential checks and notification prompts in the app.
    static func configure(_ app: XCUIApplication) {
        app.launchArguments.append("-fitlog-ui-testing")
        app.launchEnvironment["FITLOG_UI_TESTING"] = "1"
    }

    @MainActor
    static func launchConfiguredApp(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        configure(app)
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 30),
            "Main tab bar should appear after launch (UI test login bypass).",
            file: file,
            line: line
        )
        return app
    }

    @MainActor
    static func tapTab(_ name: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(name) tab should exist", file: file, line: line)
        tab.tap()
    }

    @MainActor
    static func attachScreenshot(_ app: XCUIApplication, name: String, in test: XCTestCase) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    /// First matching control by accessibility identifier, then label.
    @MainActor
    static func control(
        _ app: XCUIApplication,
        identifier: String,
        label: String
    ) -> XCUIElement {
        let buttonByID = app.buttons[identifier]
        if buttonByID.waitForExistence(timeout: 2) {
            return buttonByID
        }
        let anyByID = app.descendants(matching: .any)[identifier]
        if anyByID.waitForExistence(timeout: 1) {
            return anyByID
        }
        return app.buttons[label]
    }
}
