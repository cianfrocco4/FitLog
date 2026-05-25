//
//  ProgramBuilderFloatingActionBar.swift
//  FitLog
//
//  Persistent summary + primary CTA for the program builder review step.
//

import SwiftUI

struct ProgramBuilderFloatingActionBar: View {
    let summaryLine: String
    let validationResult: ProgramValidationResult
    let primaryTitle: String
    let isPrimaryDisabled: Bool
    let isLoading: Bool
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                validationIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(summaryLine)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(validationCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Button(action: onPrimary) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(primaryTitle)
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPrimaryDisabled || isLoading)
                .accessibilityLabel(primaryTitle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var validationIcon: some View {
        if validationResult.canSaveToPlan {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(FitlogPalette.success)
                .font(.title3)
                .accessibilityHidden(true)
        } else if !validationResult.blockingIssues.isEmpty {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(FitlogPalette.caution)
                .font(.title3)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
                .font(.title3)
                .accessibilityHidden(true)
        }
    }

    private var validationCaption: String {
        if validationResult.canSaveToPlan {
            return "Ready to save"
        }
        if let issue = validationResult.blockingIssues.first {
            return issue
        }
        if let warning = validationResult.warningIssues.first {
            return warning
        }
        return "Review before saving"
    }
}
