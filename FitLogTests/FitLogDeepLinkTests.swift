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

    @Test func parsesUITestTabDeepLinks() {
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/home")!) == .uitestTab(.home))
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/plan")!) == .uitestTab(.plan))
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/history")!) == .uitestTab(.history))
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/coach")!) == .uitestTab(.coach))
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/more")!) == .uitestTab(.more))
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/HISTORY")!) == .uitestTab(.history))
    }

    @Test func rejectsUnknownUITestPaths() {
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/tab/settings")!) == nil)
        #expect(FitLogDeepLink(url: URL(string: "fitlog://uitest/home")!) == nil)
    }
}
