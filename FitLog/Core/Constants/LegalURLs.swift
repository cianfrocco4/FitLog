//
//  LegalURLs.swift
//  FitLog
//
//  Canonical Privacy Policy, Terms of Use (EULA), and Support URLs (Guideline 3.1.2(c)).
//

import Foundation

enum LegalURLs {
    static let privacyPolicy = URL(string: "https://cianfrocco4.github.io/FitLog/privacy-policy.html")!
    /// Apple Standard Licensed Application End User License Agreement.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let support = URL(string: "https://cianfrocco4.github.io/FitLog/support.html")!

    enum Link: String, CaseIterable, Identifiable, Sendable {
        case termsOfUse
        case privacyPolicy
        case support

        var id: String { rawValue }

        var title: String {
            switch self {
            case .termsOfUse: return "Terms of Use"
            case .privacyPolicy: return "Privacy Policy"
            case .support: return "Support"
            }
        }

        var url: URL {
            switch self {
            case .termsOfUse: return LegalURLs.termsOfUse
            case .privacyPolicy: return LegalURLs.privacyPolicy
            case .support: return LegalURLs.support
            }
        }

        var systemImage: String {
            switch self {
            case .termsOfUse: return "doc.text"
            case .privacyPolicy: return "hand.raised"
            case .support: return "questionmark.circle"
            }
        }

        var accessibilityHint: String {
            switch self {
            case .termsOfUse:
                return "Opens the Apple Standard Terms of Use (EULA) in Safari"
            case .privacyPolicy:
                return "Opens the Workout Log AI privacy policy in Safari"
            case .support:
                return "Opens Workout Log AI support in Safari"
            }
        }
    }
}
