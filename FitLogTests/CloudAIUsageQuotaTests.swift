//
//  CloudAIUsageQuotaTests.swift
//  FitLogTests
//

import Foundation
import Testing
@testable import FitLog

struct CloudAIUsageQuotaTests {

    @Test func consume_enforcesDailyLimit() {
        let suite = "CloudAIUsageQuotaTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer {
            defaults.removePersistentDomain(forName: suite)
        }

        let kind = CloudAIUsageKind.coachChat
        let limit = CloudAIUsageQuota.dailyLimit(for: kind)
        for _ in 0..<limit {
            #expect(CloudAIUsageQuota.consume(kind, defaults: defaults))
        }
        #expect(!CloudAIUsageQuota.canConsume(kind, defaults: defaults))
        #expect(!CloudAIUsageQuota.consume(kind, defaults: defaults))
        #expect(CloudAIUsageQuota.remaining(for: kind, defaults: defaults) == 0)
    }
}
