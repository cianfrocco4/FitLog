//
//  PremiumGatingSmokeTests.swift
//  FitLogTests
//

import Testing
@testable import FitLog

struct PremiumGatingSmokeTests {

    @Test func freeUser_coachFeature_isLocked() {
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .aiCoach))
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .aiProgramGeneration))
    }

    @Test func premiumFeature_requiredTier_isPremium() {
        #expect(PremiumFeature.aiCoach.requiredTier == .premium)
        #expect(PremiumFeature.readinessTrends.requiredTier == .premium)
    }

    @Test @MainActor func premiumUser_hasAccessWhenFlagSet() {
        let store = EntitlementStore()
        store.setPremiumForTesting(true)
        #expect(store.isPremium)
        #expect(EntitlementStore.grantsAccess(isPremium: store.isPremium, to: .aiCoach))
    }
}
