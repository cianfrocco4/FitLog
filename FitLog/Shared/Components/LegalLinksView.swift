//
//  LegalLinksView.swift
//  FitLog
//
//  Functional Terms of Use and Privacy Policy links for subscription surfaces.
//

import SwiftUI

struct LegalLinkRow: View {
    let link: LegalURLs.Link

    var body: some View {
        Link(destination: link.url) {
            Label(link.title, systemImage: link.systemImage)
        }
        .accessibilityLabel(link.title)
        .accessibilityHint(link.accessibilityHint)
    }
}

struct LegalLinksView: View {
    enum Style {
        case compact
        case stacked
    }

    var style: Style = .compact
    var links: [LegalURLs.Link] = [.termsOfUse, .privacyPolicy]

    var body: some View {
        Group {
            switch style {
            case .compact:
                HStack(spacing: 16) {
                    ForEach(links) { link in
                        compactLink(link)
                    }
                }
            case .stacked:
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(links) { link in
                        compactLink(link)
                    }
                }
            }
        }
        .font(.caption)
    }

    private func compactLink(_ link: LegalURLs.Link) -> some View {
        Link(link.title, destination: link.url)
            .accessibilityLabel(link.title)
            .accessibilityHint(link.accessibilityHint)
    }
}

#Preview("Compact") {
    LegalLinksView(style: .compact)
        .padding()
}

#Preview("Compact Dark") {
    LegalLinksView(style: .compact)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Stacked") {
    LegalLinksView(style: .stacked)
        .padding()
}

#Preview("Form rows") {
    Form {
        Section("Legal") {
            LegalLinkRow(link: .termsOfUse)
            LegalLinkRow(link: .privacyPolicy)
            LegalLinkRow(link: .support)
        }
    }
}
