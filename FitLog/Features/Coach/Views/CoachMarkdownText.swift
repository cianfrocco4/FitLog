//
//  CoachMarkdownText.swift
//  FitLog
//
//  Renders assistant markdown in Coach chat bubbles.
//

import SwiftUI

struct CoachMarkdownText: View {
    let text: String
    var font: Font = .body

    var body: some View {
        Group {
            if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                Text(attributed)
            } else {
                Text(text)
            }
        }
        .font(font)
        .foregroundStyle(.primary)
        .textSelection(.enabled)
    }
}
