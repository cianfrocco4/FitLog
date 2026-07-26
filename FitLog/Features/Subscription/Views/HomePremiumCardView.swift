//
//  HomePremiumCardView.swift
//  FitLog
//
//  Dismissible Home teaser for Premium discoverability.
//

import SwiftUI

struct HomePremiumCardView: View {
    var onSeePremium: () -> Void
    var onRemindLater: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Workout Log AI Premium", systemImage: "sparkles")
                        .font(.headline)
                    Text("AI coaching, readiness trends, and full history when you want to go deeper.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss Premium card")
                .accessibilityHint("Hides this card permanently")
            }

            HStack(spacing: 12) {
                Button("See Premium", action: onSeePremium)
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Shows subscription options")

                Button("Remind me later", action: onRemindLater)
                    .buttonStyle(.bordered)
                    .accessibilityHint("Hides this card for two weeks")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    HomePremiumCardView(onSeePremium: {}, onRemindLater: {}, onDismiss: {})
        .padding()
}
