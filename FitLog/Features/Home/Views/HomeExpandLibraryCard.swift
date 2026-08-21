//
//  HomeExpandLibraryCard.swift
//  FitLog
//
//  Nudge to add a second library workout so Home isn’t stuck on a single template.
//

import SwiftUI

struct HomeExpandLibraryCard: View {
    var onAddFromTemplate: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Build out your week", systemImage: "rectangle.stack.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Add a second workout")
                        .font(.headline)
                    Text("You’ve got one saved session. Add Pull, Legs, or another template so Home isn’t just a single day on repeat.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Don't show again") {
                    onDismiss()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHint("Hides the add-a-second-workout card on Home")
            }

            Button("From template", action: onAddFromTemplate)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("home.expandLibrary.fromTemplate")
                .accessibilityHint("Opens workout templates so you can add Pull, Legs, or another session")
        }
        .homeCardTier(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.expandLibrary")
    }
}

#if DEBUG
#Preview("Light") {
    HomeExpandLibraryCard(onAddFromTemplate: {}, onDismiss: {})
        .padding()
}

#Preview("Dark") {
    HomeExpandLibraryCard(onAddFromTemplate: {}, onDismiss: {})
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Large Type") {
    HomeExpandLibraryCard(onAddFromTemplate: {}, onDismiss: {})
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
#endif
