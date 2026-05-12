//
//  SetSchemePickerView.swift
//  FitLog
//
//  Picker for rich set schemes on manual program slots.
//

import SwiftUI

struct SetSchemePickerView: View {
    @Binding var scheme: SetScheme?

    private var working: SetScheme {
        scheme ?? SetScheme(kind: .fixed)
    }

    var body: some View {
        Group {
            Picker("Set scheme", selection: Binding(
                get: { working.kind },
                set: { newKind in
                    scheme = SetScheme(
                        kind: newKind,
                        rpeTarget: newKind == .rpeBased ? (scheme?.rpeTarget ?? 8) : nil,
                        rirTarget: newKind == .rirBased ? (scheme?.rirTarget ?? 2) : nil,
                        percentOneRM: newKind == .percentOf1RM ? (scheme?.percentOneRM ?? 75) : nil,
                        dropSteps: newKind == .dropSet ? (scheme?.dropSteps ?? 2) : nil
                    )
                    if newKind == .fixed {
                        scheme = nil
                    }
                }
            )) {
                ForEach(SetSchemeKind.allCases, id: \.self) { k in
                    Text(label(for: k)).tag(k)
                }
            }
            .accessibilityHint("Chooses how sets progress for this exercise slot.")

            switch scheme?.kind ?? .fixed {
            case .fixed:
                EmptyView()
            case .rpeBased:
                Stepper(
                    "Target RPE: \(String(format: "%.1f", scheme?.rpeTarget ?? 8))",
                    value: Binding(
                        get: { scheme?.rpeTarget ?? 8 },
                        set: { scheme = SetScheme(kind: .rpeBased, rpeTarget: $0, rirTarget: nil, percentOneRM: nil, dropSteps: nil) }
                    ),
                    in: 1 ... 10,
                    step: 0.5
                )
                .accessibilityLabel("Target RPE")
            case .rirBased:
                Stepper(
                    "Target RIR: \(String(format: "%.1f", scheme?.rirTarget ?? 2))",
                    value: Binding(
                        get: { scheme?.rirTarget ?? 2 },
                        set: { scheme = SetScheme(kind: .rirBased, rpeTarget: nil, rirTarget: $0, percentOneRM: nil, dropSteps: nil) }
                    ),
                    in: 0 ... 6,
                    step: 0.5
                )
                .accessibilityLabel("Target reps in reserve")
            case .percentOf1RM:
                Stepper(
                    "Percent 1RM: \(Int(scheme?.percentOneRM ?? 75))%",
                    value: Binding(
                        get: { Int(scheme?.percentOneRM ?? 75) },
                        set: { scheme = SetScheme(kind: .percentOf1RM, rpeTarget: nil, rirTarget: nil, percentOneRM: Double($0), dropSteps: nil) }
                    ),
                    in: 40 ... 120,
                    step: 5
                )
                .accessibilityLabel("Percent of one rep max")
            case .dropSet:
                Stepper(
                    "Drop steps: \(scheme?.dropSteps ?? 2)",
                    value: Binding(
                        get: { scheme?.dropSteps ?? 2 },
                        set: { scheme = SetScheme(kind: .dropSet, rpeTarget: nil, rirTarget: nil, percentOneRM: nil, dropSteps: $0) }
                    ),
                    in: 1 ... 5
                )
                .accessibilityLabel("Number of drop steps after the top set")
            case .pyramid, .reversePyramid, .restPause, .amrap:
                Text("Uses your sets and reps fields as written.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func label(for kind: SetSchemeKind) -> String {
        switch kind {
        case .fixed: return "Fixed (sets × reps)"
        case .pyramid: return "Ascending pyramid"
        case .reversePyramid: return "Reverse pyramid"
        case .rpeBased: return "RPE-based"
        case .rirBased: return "RIR-based"
        case .percentOf1RM: return "Percent of 1RM"
        case .dropSet: return "Drop set"
        case .restPause: return "Rest-pause"
        case .amrap: return "AMRAP"
        }
    }
}
