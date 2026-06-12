//
//  HistoryKPITile.swift
//  FitLog
//

import SwiftUI

struct HistoryKPITile: View {
    let title: String
    let value: String
    let deltaLine: (String, Color)?
    let systemImage: String
    var showsInfoButton = false
    var onInfo: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                if showsInfoButton, let onInfo {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Volume calculation info")
                }
            }
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            if let deltaLine {
                Text(deltaLine.0)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(deltaLine.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .accessibilityElement(children: .combine)
    }
}
