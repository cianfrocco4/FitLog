//
//  CardioTemplatePickerView.swift
//  FitLog
//

import SwiftUI

struct CardioTemplatePickerView: View {
    let templates: [CardioWorkoutTemplate]
    let onSelect: (CardioWorkoutTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(templates) { template in
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
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
    }
}
