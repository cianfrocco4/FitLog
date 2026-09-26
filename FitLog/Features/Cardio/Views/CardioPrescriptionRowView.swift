//
//  CardioPrescriptionRowView.swift
//  FitLog
//

import SwiftUI

/// Compact prescription summary for workout plan rows and builder lists.
struct CardioPrescriptionRowView: View {
    let prescription: CardioPrescription
    var exercise: Exercise?
    /// Last working load or last cardio duration from a prior completed session.
    var lastLoadCaption: String? = nil

    private var accessibilitySummary: String {
        var parts = [
            "Cardio prescription, \(prescription.kind.displayName), \(CardioMetricsCalculator.prescriptionSummary(prescription))"
        ]
        if let lastLoadCaption, !lastLoadCaption.isEmpty {
            parts.append(lastLoadCaption)
        }
        return parts.joined(separator: ", ")
    }

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
                if let lastLoadCaption, !lastLoadCaption.isEmpty {
                    Text(lastLoadCaption)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityIdentifier(FitLogA11yID.cardioPrescriptionRow.lastLoad)
                        .accessibilityLabel(lastLoadCaption)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
    }
}
