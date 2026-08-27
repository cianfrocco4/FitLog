//
//  RestCompleteNotificationTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

@Suite struct RestCompleteNotificationTests {
    @Test func noteOpenLoggingIgnoresOtherIdentifiers() {
        RestCompleteNotification.resetPendingOpenLoggingForTests()
        RestCompleteNotification.noteOpenLoggingIfNeeded(identifier: "com.fitlog.other")
        #expect(RestCompleteNotification.pendingOpenLogging == false)
        #expect(RestCompleteNotification.consumePendingOpenLogging() == false)
    }

    @Test func noteOpenLoggingSetsPendingFlagForRestComplete() {
        RestCompleteNotification.resetPendingOpenLoggingForTests()
        RestCompleteNotification.noteOpenLoggingIfNeeded(identifier: RestCompleteNotification.identifier)
        #expect(RestCompleteNotification.pendingOpenLogging)
        #expect(RestCompleteNotification.consumePendingOpenLogging())
        #expect(RestCompleteNotification.pendingOpenLogging == false)
        #expect(RestCompleteNotification.consumePendingOpenLogging() == false)
    }

    @Test func identifierMatchesHistoricRestCompleteId() {
        #expect(RestCompleteNotification.identifier == "com.fitlog.restTimer.complete")
    }
}
