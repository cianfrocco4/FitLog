//
//  CoachChatActionCardView.swift
//  FitLog
//
//  Confirmation-gated action cards under assistant messages.
//

import SwiftUI

struct CoachChatActionCardView: View {
    let action: CoachChatAction
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(action.title, systemImage: iconName)
                .font(.subheadline.weight(.semibold))

            if let detail = action.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if action.isApplied {
                Label("Applied", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.success)
            } else {
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint("Confirm and apply this suggestion")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch action.kind {
        case .openProgramBuilder: return "calendar.badge.clock"
        case .openPlanTab: return "calendar"
        case .openHomeTab: return "house"
        }
    }
}
