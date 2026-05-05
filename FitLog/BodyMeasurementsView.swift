//
//  BodyMeasurementsView.swift
//  FitLog
//

import SwiftUI

struct BodyMeasurementsView: View {
    @Environment(DataManager.self) private var dataVM
    @EnvironmentObject private var userPreferences: UserPreferences

    @State private var showEditor = false
    @State private var entryBeingEdited: BodyMetricEntry?
    @State private var draft = BodyMetricEntry()
    @State private var weightText = ""
    @State private var waistText = ""
    @State private var chestText = ""
    @State private var hipsText = ""
    @State private var neckText = ""
    @State private var bicepsText = ""
    @State private var healthBanner: String?

    private var unitLabel: String { userPreferences.weightDisplayUnit.shortLabel }

    var body: some View {
        List {
            if let healthBanner {
                Section {
                    Text(healthBanner)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if dataVM.bodyMetricEntries.isEmpty {
                Section {
                    Text("Log body weight and optional measurements to track changes alongside your training.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(dataVM.bodyMetricEntries) { entry in
                        Button {
                            openEditor(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(HistoryView.formatDateStatic(entry.date))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if let lb = entry.bodyWeightLb {
                                    let d = WeightStoreConversion.displayValue(storedPounds: lb, unit: userPreferences.weightDisplayUnit)
                                    Text("\(WeightStoreConversion.formatDisplay(d)) \(unitLabel)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                let parts = measurementSummary(entry)
                                if !parts.isEmpty {
                                    Text(parts.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            dataVM.deleteBodyMetric(id: dataVM.bodyMetricEntries[i].id)
                        }
                    }
                }
            }
        }
        .navigationTitle("Body measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openEditor(nil)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add entry")
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                Form {
                    Section("When") {
                        DatePicker("Date", selection: Binding(
                            get: { draft.date },
                            set: { draft.date = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                    Section("Weight") {
                        HStack {
                            TextField("Optional", text: $weightText)
                                .keyboardType(.decimalPad)
                            Text(unitLabel)
                                .foregroundStyle(.secondary)
                        }
                        Button("Use latest from Apple Health") {
                            Task {
                                healthBanner = nil
                                let ok = await dataVM.healthSyncService.requestBodyMassReadAccess()
                                guard ok else {
                                    healthBanner = "Health access was not granted."
                                    return
                                }
                                guard let lb = await dataVM.healthSyncService.fetchLatestBodyMassLb() else {
                                    healthBanner = "No body mass samples found in Health."
                                    return
                                }
                                let disp = WeightStoreConversion.displayValue(
                                    storedPounds: lb,
                                    unit: userPreferences.weightDisplayUnit
                                )
                                weightText = WeightStoreConversion.formatDisplay(disp)
                            }
                        }
                        .font(.subheadline)
                    }
                    Section("Circumferences (cm)") {
                        Text("Optional — stored in centimeters.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Waist")
                            TextField("—", text: $waistText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Chest")
                            TextField("—", text: $chestText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Hips")
                            TextField("—", text: $hipsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Neck")
                            TextField("—", text: $neckText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Biceps")
                            TextField("—", text: $bicepsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .navigationTitle(entryBeingEdited == nil ? "New entry" : "Edit entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showEditor = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveDraft()
                            showEditor = false
                        }
                        .fontWeight(.semibold)
                    }
                }
                .keyboardDismissToolbar()
            }
            .presentationDetents([.large])
        }
        .onChange(of: showEditor) { _, on in
            if on {
                syncFormFromDraft()
            }
        }
    }

    private func measurementSummary(_ entry: BodyMetricEntry) -> [String] {
        var parts: [String] = []
        if let v = entry.waistCm { parts.append("Waist \(formatCm(v))") }
        if let v = entry.chestCm { parts.append("Chest \(formatCm(v))") }
        if let v = entry.hipsCm { parts.append("Hips \(formatCm(v))") }
        if let v = entry.neckCm { parts.append("Neck \(formatCm(v))") }
        if let v = entry.bicepsCm { parts.append("Arms \(formatCm(v))") }
        return parts
    }

    private func formatCm(_ cm: Double) -> String {
        let inches = cm / 2.54
        return String(format: "%.1f cm (%.1f in)", cm, inches)
    }

    private func openEditor(_ entry: BodyMetricEntry?) {
        entryBeingEdited = entry
        draft = entry ?? BodyMetricEntry()
        syncFormFromDraft()
        showEditor = true
    }

    private func syncFormFromDraft() {
        if let lb = draft.bodyWeightLb {
            let d = WeightStoreConversion.displayValue(storedPounds: lb, unit: userPreferences.weightDisplayUnit)
            weightText = WeightStoreConversion.formatDisplay(d)
        } else {
            weightText = ""
        }
        waistText = draft.waistCm.map { String(format: "%.1f", $0) } ?? ""
        chestText = draft.chestCm.map { String(format: "%.1f", $0) } ?? ""
        hipsText = draft.hipsCm.map { String(format: "%.1f", $0) } ?? ""
        neckText = draft.neckCm.map { String(format: "%.1f", $0) } ?? ""
        bicepsText = draft.bicepsCm.map { String(format: "%.1f", $0) } ?? ""
    }

    private func parseOptionalDouble(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let v = Double(t), v >= 0, v.isFinite else { return nil }
        return v
    }

    private func saveDraft() {
        var next = draft
        if let disp = parseOptionalDouble(weightText) {
            next.bodyWeightLb = WeightStoreConversion.storedPounds(
                displayValue: disp,
                unit: userPreferences.weightDisplayUnit
            )
        } else {
            next.bodyWeightLb = nil
        }
        next.waistCm = parseOptionalDouble(waistText)
        next.chestCm = parseOptionalDouble(chestText)
        next.hipsCm = parseOptionalDouble(hipsText)
        next.neckCm = parseOptionalDouble(neckText)
        next.bicepsCm = parseOptionalDouble(bicepsText)
        dataVM.upsertBodyMetric(next)
    }
}
