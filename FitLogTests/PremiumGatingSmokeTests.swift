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

    @Test func freeUser_historyAnalyticsAndExport_areLocked() {
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .unlimitedHistory))
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .advancedAnalytics))
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .dataExport))
        #expect(!EntitlementStore.grantsAccess(isPremium: false, to: .readinessTrends))
    }

    @Test func premiumFeature_requiredTier_isPremium() {
        #expect(PremiumFeature.aiCoach.requiredTier == .premium)
        #expect(PremiumFeature.readinessTrends.requiredTier == .premium)
        #expect(PremiumFeature.unlimitedHistory.requiredTier == .premium)
        #expect(PremiumFeature.advancedAnalytics.requiredTier == .premium)
        #expect(PremiumFeature.dataExport.requiredTier == .premium)
    }

    @Test @MainActor func premiumUser_hasAccessWhenFlagSet() {
        let store = EntitlementStore()
        store.setPremiumForTesting(true)
        #expect(store.isPremium)
        #expect(EntitlementStore.grantsAccess(isPremium: store.isPremium, to: .aiCoach))
        #expect(EntitlementStore.grantsAccess(isPremium: store.isPremium, to: .unlimitedHistory))
        #expect(EntitlementStore.grantsAccess(isPremium: store.isPremium, to: .dataExport))
    }

    @Test func freeTierDayRanges_onlyInclude7And14() {
        #expect(HistoryDayRange.freeTierCases == [.d7, .d14])
        #expect(HistoryDayRange.d30.requiresPremium)
        #expect(HistoryDayRange.d90.requiresPremium)
        #expect(HistoryDayRange.ytd.requiresPremium)
        #expect(!HistoryDayRange.d7.requiresPremium)
        #expect(!HistoryDayRange.d14.requiresPremium)
    }

    @Test func freeUser_proposedPremiumRanges_areRejectedWithoutMutationSemantics() {
        #expect(HistoryDayRange.allowsSelection(.d7, isPremium: false))
        #expect(HistoryDayRange.allowsSelection(.d14, isPremium: false))
        #expect(!HistoryDayRange.allowsSelection(.d30, isPremium: false))
        #expect(!HistoryDayRange.allowsSelection(.d90, isPremium: false))
        #expect(!HistoryDayRange.allowsSelection(.ytd, isPremium: false))
        #expect(HistoryDayRange.allowsSelection(.d90, isPremium: true))

        #expect(ExerciseHistoryDataScope.allowsSelection(.selectedRange, isPremium: false))
        #expect(!ExerciseHistoryDataScope.allowsSelection(.allTime, isPremium: false))
        #expect(ExerciseHistoryDataScope.allowsSelection(.allTime, isPremium: true))

        #expect(PremiumGatedSelection.shouldApply(requiresPremium: true, hasPremiumAccess: false) == false)
        #expect(PremiumGatedSelection.shouldApply(requiresPremium: true, hasPremiumAccess: true))
        #expect(PremiumGatedSelection.shouldApply(requiresPremium: false, hasPremiumAccess: false))
    }
}
