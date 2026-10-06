//
//  CardioTemplatePickerView.swift
//  FitLog
//

import SwiftUI

struct CardioTemplatePickerView: View {
    let templates: [CardioWorkoutTemplate]
    let onSelect: (CardioWorkoutTemplate) -> Void
    /// Last cardio duration from a completed session (skips interval rest).
    var lastLoadCaption: String? = nil
    /// Previews set this false so they do not need a live session store.
    var resolvesLastLoadFromEnvironment: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            lastLoadCaptionView
            ForEach(templates) { template in
                Button {
                    onSelect(template)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(template.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(template.workoutKind.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(FitlogPalette.chartSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(FitlogPalette.chartSecondary.opacity(0.12), in: Capsule())
                        }
                        Text(template.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(template.rows.count) exercise\(template.rows.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityHint("Applies this cardio template to the workout")
            }
        }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var lastLoadCaptionView: some View {
        if let lastLoadCaption, !lastLoadCaption.isEmpty {
            lastLoadLine(lastLoadCaption)
        } else if resolvesLastLoadFromEnvironment {
            CardioTemplatePickerLastLoadCaption()
        }
    }

    private func lastLoadLine(_ caption: String) -> some View {
        Text(caption)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(FitLogA11yID.cardioTemplatePicker.lastLoad)
            .accessibilityLabel(caption)
            .accessibilityHint("Last cardio duration from a completed session")
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct CardioTemplatePickerLastLoadCaption: View {
    @Environment(DataManager.self) private var dataVM

    var body: some View {
        if let lastLoad = WalnutLastWorkingLoad.lastCardioDurationCaption(
            from: dataVM.completedSessions
        ) {
            Text(lastLoad)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(FitLogA11yID.cardioTemplatePicker.lastLoad)
                .accessibilityLabel(lastLoad)
                .accessibilityHint("Last cardio duration from a completed session")
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

#if DEBUG
#Preview("Templates") {
    NavigationStack {
        CardioTemplatePickerView(
            templates: CardioTemplateLibrary.all,
            onSelect: { _ in },
            lastLoadCaption: "Last 45:00",
            resolvesLastLoadFromEnvironment: false
        )
    }
}

#Preview("Templates dark") {
    NavigationStack {
        CardioTemplatePickerView(
            templates: Array(CardioTemplateLibrary.all.prefix(2)),
            onSelect: { _ in },
            lastLoadCaption: "Last 32:00",
            resolvesLastLoadFromEnvironment: false
        )
    }
    .preferredColorScheme(.dark)
}
#endif

