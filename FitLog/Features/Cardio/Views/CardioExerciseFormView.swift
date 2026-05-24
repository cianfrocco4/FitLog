//
//  CardioExerciseFormView.swift
//  FitLog
//
//  Form for creating or editing custom cardio / hybrid exercises.
//

import SwiftUI

struct CardioExerciseFormView: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var modality: ExerciseModality
    @Binding var activityKind: CardioActivityKind
    @Binding var primaryMetric: CardioPrimaryMetric
    @Binding var equipment: CardioEquipment
    @Binding var supportsIntervals: Bool
    @Binding var estimatedMETsText: String

    var body: some View {
        Section("Exercise Info") {
            TextField("Name", text: $name)
            TextField("Description", text: $description, axis: .vertical)
        }

        Section("Modality") {
            Picker("Type", selection: $modality) {
                Text("Cardio").tag(ExerciseModality.cardio)
                Text("Hybrid").tag(ExerciseModality.hybrid)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Exercise modality")
            .accessibilityHint("Cardio for endurance-only logging; hybrid for mixed strength and cardio sessions.")
        }

        Section("Cardio Details") {
            Picker("Activity", selection: $activityKind) {
                ForEach(CardioActivityKind.allCases) { kind in
                    Label(kind.displayName, systemImage: kind.systemImage).tag(kind)
                }
            }
            Picker("Primary metric", selection: $primaryMetric) {
                ForEach(CardioPrimaryMetric.allCases) { metric in
                    Text(metric.displayName).tag(metric)
                }
            }
            Picker("Equipment", selection: $equipment) {
                ForEach(CardioEquipment.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            Toggle("Supports intervals", isOn: $supportsIntervals)
            TextField("Estimated METs (optional)", text: $estimatedMETsText)
                .keyboardType(.decimalPad)
        }
    }

    /// Builds metadata from current bindings; returns nil when METs text is invalid non-empty input.
    static func buildMetadata(
        activityKind: CardioActivityKind,
        primaryMetric: CardioPrimaryMetric,
        equipment: CardioEquipment,
        supportsIntervals: Bool,
        estimatedMETsText: String
    ) -> CardioExerciseMetadata? {
        let trimmedMETs = estimatedMETsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let mets: Double?
        if trimmedMETs.isEmpty {
            mets = nil
        } else if let value = Double(trimmedMETs), value > 0 {
            mets = value
        } else {
            return nil
        }
        return CardioExerciseMetadata(
            activityKind: activityKind,
            primaryMetric: primaryMetric,
            equipment: equipment,
            estimatedMETs: mets,
            supportsIntervals: supportsIntervals,
            hkActivityTypeRaw: activityKind.rawValue
        )
    }
}

#Preview("Cardio form") {
    @Previewable @State var name = "Trail Run"
    @Previewable @State var description = "Easy trail"
    @Previewable @State var modality = ExerciseModality.cardio
    @Previewable @State var activity = CardioActivityKind.run
    @Previewable @State var metric = CardioPrimaryMetric.distance
    @Previewable @State var equipment = CardioEquipment.outdoor
    @Previewable @State var intervals = true
    @Previewable @State var mets = "9.5"

    NavigationStack {
        Form {
            CardioExerciseFormView(
                name: $name,
                description: $description,
                modality: $modality,
                activityKind: $activity,
                primaryMetric: $metric,
                equipment: $equipment,
                supportsIntervals: $intervals,
                estimatedMETsText: $mets
            )
        }
        .navigationTitle("New Cardio")
    }
}
