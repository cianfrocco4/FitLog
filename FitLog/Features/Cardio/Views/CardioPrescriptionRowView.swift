//
//  CardioPrescriptionRowView.swift
//  FitLog
//

import SwiftUI

/// Compact prescription summary for workout plan rows and builder lists.
struct CardioPrescriptionRowView: View {
    let prescription: CardioPrescription
    var exercise: Exercise?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let activity = exercise?.cardioMetadata?.activityKind {
                Image(systemName: activity.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.chartSecondary)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.chartSecondary)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(prescription.kind.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FitlogPalette.chartSecondary)
                Text(CardioMetricsCalculator.prescriptionSummary(prescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Cardio prescription, \(prescription.kind.displayName), \(CardioMetricsCalculator.prescriptionSummary(prescription))")
    }
}
