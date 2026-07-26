//
//  EntitlementStoreTests.swift
//  FitLogTests
//

import Foundation
import SwiftUI
import Testing
@testable import FitLog

struct EntitlementStoreTests {

    @Test func grantsAccess_freeUser_deniesPremiumFeatures() {
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .aiCoach))
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .readinessTrends))
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .dataExport))
    }

    @Test func grantsAccess_premiumUser_grantsAllFeatures() {
        for feature in PremiumFeature.allCases {
            #expect(EntitlementStore.grantsAccess(isPremium: true, to: feature))
        }
    }

    @Test @MainActor func isPremiumFlag_reflectsTestingOverride() {
        let store = EntitlementStore()
        store.setPremiumForTesting(false)
        #expect(!store.isPremium)
        store.setPremiumForTesting(true)
        #expect(store.isPremium)
    }

    @Test func paywallGateLogic_freeUser_blocksCoach() {
        let allowed = EntitlementStore.grantsAccess(isPremium: false, to: .aiCoach)
        #expect(!allowed)
    }
}
