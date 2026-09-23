//
//  PlateCalculatorSheet.swift
//  FitLog
//

import SwiftUI

struct PlateCalculatorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let displayUnit: WeightDisplayUnit
    /// Suggested target from the log screen (display units).
    let suggestedTargetDisplay: Double?
    /// Last working load caption from a prior completed session (optional).
    var lastLoadCaption: String? = nil
    /// Last working-set total in display units, used to seed / apply “Use last load”.
    var lastLoadDisplayWeight: Double? = nil
    let onApplyDisplayWeight: (Double) -> Void

    @State private var barDisplay: Double
    @State private var targetTotalDisplay: Double

    init(
        displayUnit: WeightDisplayUnit,
        suggestedTargetDisplay: Double?,
        lastLoadCaption: String? = nil,
        lastLoadDisplayWeight: Double? = nil,
        onApplyDisplayWeight: @escaping (Double) -> Void
    ) {
        self.displayUnit = displayUnit
        self.suggestedTargetDisplay = suggestedTargetDisplay
        self.lastLoadCaption = lastLoadCaption
        self.lastLoadDisplayWeight = lastLoadDisplayWeight
        self.onApplyDisplayWeight = onApplyDisplayWeight
        let bar = PlateCalculator.defaultBarWeight(unit: displayUnit)
        _barDisplay = State(initialValue: bar)
        let last = lastLoadDisplayWeight.flatMap { $0 > 0 ? $0 : nil }
        let target = suggestedTargetDisplay.flatMap { $0 > 0 ? $0 : nil } ?? last ?? bar
        _targetTotalDisplay = State(initialValue: max(bar, target))
    }

    private var plan: [(size: Double, count: Int)] {
        PlateCalculator.platesPerSide(
            targetTotalDisplay: targetTotalDisplay,
            barDisplay: barDisplay,
            unit: displayUnit
        )
    }

    private var achievedTotal: Double {
        PlateCalculator.totalBarbellDisplay(barDisplay: barDisplay, platesPerSide: plan)
    }

    private var remainder: Double {
        PlateCalculator.remainderDisplay(
            targetTotalDisplay: targetTotalDisplay,
            barDisplay: barDisplay,
            unit: displayUnit
        )
    }

    private var unitLabel: String { displayUnit.shortLabel }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter bar weight and target barbell total. Plate sizes match common \(unitLabel) racks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let lastLoadCaption, !lastLoadCaption.isEmpty {
                        Text(lastLoadCaption)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(FitLogA11yID.plateCalculator.lastLoad)
                    }
                }
                Section("Bar") {
                    HStack {
                        Text("Bar weight")
                        Spacer()
                        TextField(
                            "Bar",
                            value: $barDisplay,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 72)
                        Text(unitLabel)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Target") {
                    HStack {
                        Text("Total load")
                        Spacer()
                        TextField(
                            "Target",
                            value: $targetTotalDisplay,
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 72)
                        Text(unitLabel)
                            .foregroundStyle(.secondary)
                    }
                    if let last = lastLoadDisplayWeight, last > 0 {
                        Button("Use last load (\(WeightStoreConversion.formatDisplay(last)) \(unitLabel))") {
                            targetTotalDisplay = max(barDisplay, last)
                        }
                        .font(.caption)
                        .accessibilityIdentifier(FitLogA11yID.plateCalculator.useLastLoad)
                        .accessibilityLabel(
                            "Use last load, \(WeightStoreConversion.formatDisplay(last)) \(unitLabel)"
                        )
                        .accessibilityHint("Fills the target from your last working set")
                    }
                    if let s = suggestedTargetDisplay, s > 0 {
                        Button("Use log screen weight (\(WeightStoreConversion.formatDisplay(s)) \(unitLabel))") {
                            targetTotalDisplay = max(barDisplay, s)
                        }
                        .font(.caption)
                    }
                }
                Section("Per side") {
                    if plan.isEmpty {
                        Text("No plates needed (target equals bar or below).")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plan.indices, id: \.self) { i in
                            let row = plan[i]
                            HStack {
                                Text("\(WeightStoreConversion.formatDisplay(row.size)) \(unitLabel)")
                                Spacer()
                                Text("× \(row.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Check") {
                    LabeledContent("Barbell total") {
                        Text("\(WeightStoreConversion.formatDisplay(achievedTotal)) \(unitLabel)")
                            .fontWeight(.medium)
                    }
                    if abs(remainder) > 0.001 {
                        Text("Target differs by \(WeightStoreConversion.formatDisplay(abs(remainder))) \(unitLabel) (not all racks match every increment).")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Plate calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use \(WeightStoreConversion.formatDisplay(achievedTotal)) \(unitLabel)") {
                        onApplyDisplayWeight(achievedTotal)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .keyboardDismissToolbar()
        }
    }
}
