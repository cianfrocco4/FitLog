//
//  CardioIntervalEditorView.swift
//  FitLog
//

import SwiftUI

/// Edits a `CardioPrescription` for steady, interval, or custom cardio rows.
struct CardioIntervalEditorView: View {
    @Binding var prescription: CardioPrescription
    /// When true, omits the outer `Form` so this view can be embedded in a parent form.
    var embedInParentForm: Bool = false

    @State private var workSecondsText = ""
    @State private var restSecondsText = ""
    @State private var repeatCountText = "8"
    @State private var durationMinutesText = ""
    @State private var distanceKmText = ""
    @State private var paceMinutesText = ""
    @State private var paceSecondsText = ""
    @State private var notesText = ""

    var body: some View {
        Group {
            if embedInParentForm {
                editorSections
            } else {
                Form { editorSections }
            }
        }
        .onAppear(perform: loadFieldsFromPrescription)
        .onChange(of: prescription.kind) { _, _ in
            syncPrescriptionFromFields()
        }
    }

    @ViewBuilder
    private var editorSections: some View {
        Section {
            Picker("Prescription type", selection: $prescription.kind) {
                ForEach(CardioPrescriptionKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .accessibilityLabel("Prescription type")
        }

        switch prescription.kind {
        case .steadyState:
            steadyStateSections
        case .intervals:
            intervalSections
        case .circuit, .custom:
            customSections
        }
    }

    private var steadyStateSections: some View {
        Group {
            Section("Targets") {
                TextField("Duration (minutes)", text: $durationMinutesText)
                    .keyboardType(.numberPad)
                    .onChange(of: durationMinutesText) { _, _ in syncPrescriptionFromFields() }
                TextField("Distance (km)", text: $distanceKmText)
                    .keyboardType(.decimalPad)
                    .onChange(of: distanceKmText) { _, _ in syncPrescriptionFromFields() }
                HStack {
                    TextField("Pace min", text: $paceMinutesText)
                        .keyboardType(.numberPad)
                    Text(":")
                    TextField("sec / km", text: $paceSecondsText)
                        .keyboardType(.numberPad)
                }
                .onChange(of: paceMinutesText) { _, _ in syncPrescriptionFromFields() }
                .onChange(of: paceSecondsText) { _, _ in syncPrescriptionFromFields() }
                Picker("Target zone", selection: zoneBinding) {
                    Text("None").tag(Optional<CardioIntensityZone>.none)
                    ForEach(CardioIntensityZone.allCases) { zone in
                        Text(zone.displayName).tag(Optional(zone))
                    }
                }
            }
            notesSection
        }
    }

    private var intervalSections: some View {
        Group {
            Section("Interval") {
                TextField("Work (seconds)", text: $workSecondsText)
                    .keyboardType(.numberPad)
                    .onChange(of: workSecondsText) { _, _ in syncPrescriptionFromFields() }
                TextField("Rest (seconds)", text: $restSecondsText)
                    .keyboardType(.numberPad)
                    .onChange(of: restSecondsText) { _, _ in syncPrescriptionFromFields() }
                TextField("Rounds", text: $repeatCountText)
                    .keyboardType(.numberPad)
                    .onChange(of: repeatCountText) { _, _ in syncPrescriptionFromFields() }
                Picker("Target zone", selection: zoneBinding) {
                    Text("None").tag(Optional<CardioIntensityZone>.none)
                    ForEach(CardioIntensityZone.allCases) { zone in
                        Text(zone.displayName).tag(Optional(zone))
                    }
                }
            }
            notesSection
        }
    }

    private var customSections: some View {
        Group {
            Section("Targets") {
                TextField("Duration (minutes)", text: $durationMinutesText)
                    .keyboardType(.numberPad)
                    .onChange(of: durationMinutesText) { _, _ in syncPrescriptionFromFields() }
            }
            notesSection
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Coach notes", text: $notesText, axis: .vertical)
                .onChange(of: notesText) { _, _ in syncPrescriptionFromFields() }
        }
    }

    private var zoneBinding: Binding<CardioIntensityZone?> {
        Binding(
            get: { prescription.targetZone },
            set: {
                prescription.targetZone = $0
                syncPrescriptionFromFields()
            }
        )
    }

    private func loadFieldsFromPrescription() {
        if let sec = prescription.targetDurationSec {
            durationMinutesText = String(max(0, sec / 60))
        }
        if let m = prescription.targetDistanceM {
            distanceKmText = String(format: "%.2f", m / 1000)
        }
        if let pace = prescription.targetPaceSecPerKm {
            paceMinutesText = String(pace / 60)
            paceSecondsText = String(format: "%02d", pace % 60)
        }
        notesText = prescription.notes ?? ""
        if let spec = prescription.intervals.first {
            if let work = spec.workDurationSec { workSecondsText = String(work) }
            if let rest = spec.restDurationSec { restSecondsText = String(rest) }
            repeatCountText = String(max(1, spec.repeatCount))
        }
    }

    private func syncPrescriptionFromFields() {
        let notes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        prescription.notes = notes.isEmpty ? nil : notes

        switch prescription.kind {
        case .steadyState:
            prescription.targetDurationSec = Int(durationMinutesText).map { max(0, $0) * 60 }
            prescription.targetDistanceM = Double(distanceKmText).map { max(0, $0) * 1000 }
            prescription.targetPaceSecPerKm = parsedPaceSecPerKm()
            prescription.intervals = []

        case .intervals:
            let work = Int(workSecondsText).map { max(1, $0) } ?? 30
            let rest = Int(restSecondsText).map { max(0, $0) } ?? 30
            let repeats = Int(repeatCountText).map { max(1, $0) } ?? 8
            prescription.intervals = [
                CardioIntervalSpec(
                    workDurationSec: work,
                    restDurationSec: rest,
                    targetZone: prescription.targetZone,
                    repeatCount: repeats
                ),
            ]
            prescription.targetDurationSec = nil
            prescription.targetDistanceM = nil

        case .circuit, .custom:
            prescription.targetDurationSec = Int(durationMinutesText).map { max(0, $0) * 60 }
            prescription.intervals = []
        }
    }

    private func parsedPaceSecPerKm() -> Int? {
        guard let min = Int(paceMinutesText), let sec = Int(paceSecondsText) else { return nil }
        let total = min * 60 + sec
        return total > 0 ? total : nil
    }
}
