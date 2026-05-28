//
//  AIServiceErrorTests.swift
//  FitLogTests
//

import XCTest
@testable import FitLog

final class AIServiceErrorTests: XCTestCase {
    func testTimeoutSuggestsLocalPresetFallback() {
        XCTAssertTrue(AIServiceError.timeout.suggestsLocalPresetFallback)
    }

    func testProxyUnavailableSuggestsLocalPresetFallback() {
        XCTAssertTrue(AIServiceError.proxyUnavailable.suggestsLocalPresetFallback)
    }

    func testInvalidJSONContentSuggestsLocalPresetFallback() {
        XCTAssertTrue(AIServiceError.invalidJSONContent.suggestsLocalPresetFallback)
    }

    func testNotConfiguredDoesNotSuggestFallback() {
        XCTAssertFalse(AIServiceError.notConfigured.suggestsLocalPresetFallback)
    }

    func testTimeoutErrorDescriptionIsActionable() {
        let message = AIServiceError.timeout.errorDescription ?? ""
        XCTAssertTrue(message.localizedCaseInsensitiveContains("waking"))
    }
}
