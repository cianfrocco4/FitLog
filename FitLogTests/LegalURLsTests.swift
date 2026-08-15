//
//  LegalURLsTests.swift
//  FitLogTests
//
//  Guideline 3.1.2(c) — Terms of Use and Privacy Policy URLs plus subscription disclosures.
//

import Testing
@testable import FitLog

struct LegalURLsTests {

    @Test func privacyPolicyURL_isHostedGitHubPages() {
        #expect(LegalURLs.privacyPolicy.absoluteString == "https://cianfrocco4.github.io/FitLog/privacy-policy.html")
        #expect(LegalURLs.privacyPolicy.scheme == "https")
    }

    @Test func termsOfUseURL_isAppleStandardEULA() {
        #expect(LegalURLs.termsOfUse.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        #expect(LegalURLs.termsOfUse.scheme == "https")
    }

    @Test func supportURL_isHostedGitHubPages() {
        #expect(LegalURLs.support.absoluteString == "https://cianfrocco4.github.io/FitLog/support.html")
    }

    @Test func requiredGuideline312cLinkTitles() {
        #expect(LegalURLs.Link.termsOfUse.title == "Terms of Use")
        #expect(LegalURLs.Link.privacyPolicy.title == "Privacy Policy")
        #expect(LegalURLs.Link.termsOfUse.url == LegalURLs.termsOfUse)
        #expect(LegalURLs.Link.privacyPolicy.url == LegalURLs.privacyPolicy)
    }

    @Test func legalLinks_haveAccessibilityHints() {
        for link in LegalURLs.Link.allCases {
            #expect(!link.accessibilityHint.isEmpty)
            #expect(link.accessibilityHint.localizedCaseInsensitiveContains("Safari"))
        }
    }
}

struct SubscriptionCatalogTests {

    @Test func autoRenewableProductIDs_matchRevenueCatMonthlyAndAnnual() {
        let ids = SubscriptionCatalog.autoRenewableProductIDs
        #expect(ids == [
            RevenueCatConfig.monthlyProductID,
            RevenueCatConfig.annualProductID
        ])
        #expect(!ids.contains(RevenueCatConfig.lifetimeProductID))
    }

    @Test func autoRenewablePlans_discloseTitleLengthAndPrice() {
        #expect(SubscriptionCatalog.autoRenewablePlans.count == 2)
        for plan in SubscriptionCatalog.autoRenewablePlans {
            #expect(!plan.title.isEmpty)
            #expect(!plan.duration.isEmpty)
            #expect(!plan.listPriceUSD.isEmpty)
            #expect(plan.disclosure.contains(plan.listPriceUSD))
            #expect(plan.disclosure.localizedCaseInsensitiveContains("auto-renew"))
        }
    }

    @Test func monthlyPlan_isOneMonthWithTrialDisclosure() {
        let monthly = SubscriptionCatalog.autoRenewablePlans.first { $0.productID == RevenueCatConfig.monthlyProductID }
        #expect(monthly?.title == "Premium Monthly")
        #expect(monthly?.duration == "1 month")
        #expect(monthly?.listPriceUSD == "$5.99")
        #expect(monthly?.disclosure.contains("14 days free") == true)
    }

    @Test func annualPlan_isOneYearWithTrialDisclosure() {
        let annual = SubscriptionCatalog.autoRenewablePlans.first { $0.productID == RevenueCatConfig.annualProductID }
        #expect(annual?.title == "Premium Annual")
        #expect(annual?.duration == "1 year")
        #expect(annual?.listPriceUSD == "$49.99")
        #expect(annual?.disclosure.contains("14 days free") == true)
    }
}
