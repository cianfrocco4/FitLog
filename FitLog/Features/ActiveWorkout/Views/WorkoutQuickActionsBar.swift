//
//  WorkoutQuickActionsBar.swift
//  FitLog
//
//  Horizontal contextual chips: bodyweight mode, RPE strip, plate calculator, notes, full log.
//

import SwiftUI

struct WorkoutQuickActionsBar: View {
    let bodyweightMode: Bool
    let rpeExpanded: Bool
    /// Display value for current effort (RPE or RIR per user preference), when set.
    let effortValueSummary: String?
    let effortKindLabel: String
    let onToggleBodyweight: () -> Void
    let onToggleRPE: () -> Void
    let onPlates: () -> Void
    let onNotes: () -> Void
    let onFullLog: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(
                    title: bodyweightMode ? "BW on" : "BW",
                    systemImage: "figure.strengthtraining.traditional",
                    isOn: bodyweightMode,
                    action: onToggleBodyweight,
                    accessibilityLabel: bodyweightMode ? "Bodyweight mode on" : "Bodyweight mode off",
                    accessibilityHint: "Double tap to toggle bodyweight logging with added or assisted load"
                )
                chip(
                    title: rpeChipTitle,
                    systemImage: "gauge.with.dots.needle.67percent",
                    isOn: rpeExpanded,
                    action: onToggleRPE,
                    accessibilityLabel: rpeExpanded ? "Hide \(effortKindLabel) picker" : "Show \(effortKindLabel) picker",
                    accessibilityHint: "Double tap to show or hide quick effort chips"
                )
                chip(
                    title: "Plates",
                    systemImage: "scalemass",
                    isOn: false,
                    action: onPlates,
                    accessibilityLabel: "Plate calculator",
                    accessibilityHint: "Double tap to open the plate calculator for this set"
                )
                chip(
                    title: "Notes",
                    systemImage: "note.text",
                    isOn: false,
                    action: onNotes,
                    accessibilityLabel: "Exercise notes",
                    accessibilityHint: "Double tap to expand notes and configuration for this exercise"
                )
                chip(
                    title: "Full log",
                    systemImage: "slider.horizontal.3",
                    isOn: false,
                    action: onFullLog,
                    accessibilityLabel: "Full set log",
                    accessibilityHint: "Double tap for RPE, drop sets, timed sets, and advanced options"
                )
            }
            .padding(.vertical, 2)
        }
    }

    private var rpeChipTitle: String {
        if rpeExpanded {
            return "\(effortKindLabel) hide"
        }
        if let s = effortValueSummary, !s.isEmpty {
            return "\(effortKindLabel) \(s)"
        }
        return effortKindLabel
    }

    private func chip(
        title: String,
        systemImage: String,
        isOn: Bool,
        action: @escaping () -> Void,
        accessibilityLabel: String,
        accessibilityHint: String
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isOn ? Color.accentColor.opacity(0.22) : Color(.systemGray5))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isOn ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview("Light") {
    WorkoutQuickActionsBar(
        bodyweightMode: false,
        rpeExpanded: true,
        effortValueSummary: "8",
        effortKindLabel: "RPE",
        onToggleBodyweight: {},
        onToggleRPE: {},
        onPlates: {},
        onNotes: {},
        onFullLog: {}
    )
    .padding()
}

#Preview("Dark") {
    WorkoutQuickActionsBar(
        bodyweightMode: true,
        rpeExpanded: false,
        effortValueSummary: nil,
        effortKindLabel: "RIR",
        onToggleBodyweight: {},
        onToggleRPE: {},
        onPlates: {},
        onNotes: {},
        onFullLog: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
