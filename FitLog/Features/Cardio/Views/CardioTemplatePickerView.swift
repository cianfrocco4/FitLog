//
//  CardioTemplatePickerView.swift
//  FitLog
//

import SwiftUI

struct CardioTemplatePickerView: View {
    let templates: [CardioWorkoutTemplate]
    let onSelect: (CardioWorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(DataManager.self) private var dataVM

    var body: some View {
        List(templates) { template in
            let lastDuration = DraftLastSessionWorkingCopy.lastCardioDurationLine(
                matchingTemplateName: template.name,
                in: dataVM.completedSessions
            )
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
                    if let lastDuration {
                        Text(lastDuration)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(FitlogPalette.chartSecondary)
                            .accessibilityIdentifier(FitLogA11yID.cardioTemplatePickerLastDuration)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityHint(
                lastDuration.map { "Applies this cardio template to the workout. \($0)" }
                    ?? "Applies this cardio template to the workout"
            )
            .accessibilityLabel(
                lastDuration.map { "\(template.name). \(template.subtitle). \($0)" }
                    ?? "\(template.name). \(template.subtitle)"
            )
        }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
    }
}
