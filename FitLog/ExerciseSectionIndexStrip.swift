//
//  ExerciseSectionIndexStrip.swift
//  FitLog
//

import SwiftUI

struct ExerciseSectionIndexStrip: View {
    let proxy: ScrollViewProxy
    let ids: [String]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(ids, id: \.self) { id in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                } label: {
                    Text(Self.indexLabel(for: id))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 4)
    }

    private static func indexLabel(for id: String) -> String {
        switch id {
        case "favorites": return "★"
        case "recent": return "○"
        default: return String(id.prefix(1)).uppercased()
        }
    }
}
