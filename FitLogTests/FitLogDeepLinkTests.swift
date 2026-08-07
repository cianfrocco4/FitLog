//
//  FitLogDeepLinkTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct FitLogDeepLinkTests {

    @Test func parsesQuickLog() {
        #expect(FitLogDeepLink(url: URL(string: "fitlog://quick-log")!) == .quickLog)
    }

    @Test func parsesOpenAndHome() {
        #expect(FitLogDeepLink(url: URL(string: "fitlog://open")!) == .open)
        #expect(FitLogDeepLink(url: URL(string: "fitlog://home")!) == .open)
        #expect(FitLogDeepLink(url: URL(string: "fitlog://OPEN")!) == .open)
    }

    @Test func rejectsUnknownHostAndScheme() {
        #expect(FitLogDeepLink(url: URL(string: "fitlog://unknown")!) == nil)
        #expect(FitLogDeepLink(url: URL(string: "https://example.com/open")!) == nil)
    }
}
