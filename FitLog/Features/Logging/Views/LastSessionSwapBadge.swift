//
//  LastSessionSwapBadge.swift
//  FitLog
//

import SwiftUI

struct LastSessionSwapBadge: View {
    var body: some View {
        Text("Last time")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(FitlogPalette.highlight.opacity(0.18), in: Capsule())
            .foregroundStyle(FitlogPalette.highlight)
            .accessibilityHidden(true)
    }
}
