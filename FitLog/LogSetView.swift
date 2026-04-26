//
//  LogSetView.swift
//  FitLog
//
//  Created by Anthony Cianfrocco on 2/24/26.
//

import SwiftUI

private struct EditableDropRow: Identifiable {
    let id: UUID
    var weight: Double
    var reps: Int

    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 0) {
        self.id = id
        self.weight = weight
        self.reps = reps
    }
}

private struct SupersetPosition {
    let exerciseIndex: Int
    let totalInRound: Int
    let isLastInRound: Bool
}

struct LogSetView: View {
    /// Passed in instead of `@EnvironmentObject` so rest/workout timers on the session VM do not
    /// re-render this sheet every second (which could re-run `onAppear` and wipe weight while typing).
    let sessionVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var userPreferences: UserPreferences
    @Environment(\.dismiss) var dismiss

    let exerciseIndex: Int
    /// When opening from inline quick-entry, seed weight/reps after normal prefill.
    var prefillDisplayWeight: Double? = nil
    var prefillReps: Int? = nil
    /// Reps-first layout with optional added vs assisted load (net stored as signed weight).
    var prefillBodyweightMode: Bool = false

    @State private var weight: Double = 0.0
    @State private var reps: Int = 0
    @State private var restTime: Int = 90
    @State private var isWarmup: Bool = false
    /// Field name -> value for this set.
    @State private var configValues: [String: String] = [:]
    @State private var dropSetEnabled = false
    @State private var dropRows: [EditableDropRow] = []
    /// Manual override for superset rest. `nil` = use auto-determined value.
    @State private var restOverride: Bool?
    /// Optional RPE 6–10; `nil` means not recorded.
    @State private var rpeChoice: Int? = nil
    @State private var showPlateCalculator = false
    @State private var bodyweightMode = false
    @State private var bwAddedDisplay: Double = 0
    @State private var bwAssistedDisplay: Double = 0

    private var displayUnit: WeightDisplayUnit { userPreferences.weightDisplayUnit }

    private var displayWeightRange: ClosedRange<Double> {
        WeightStoreConversion.displayRange(unit: displayUnit)
    }

    private var weightStep: Double {
        WeightStoreConversion.stepperStep(unit: displayUnit)
    }

    private var unitShortLabel: String { displayUnit.shortLabel }

    private var workoutExercise: WorkoutExercise? {
        guard let session = sessionVM.currentSession, exerciseIndex < session.exerciseLogs.count else { return nil }
        return session.exerciseLogs[exerciseIndex].workoutExercise
    }

    private var isSupersetContext: Bool {
        supersetPosition != nil
    }

    private var supersetPosition: SupersetPosition? {
        guard let session = sessionVM.currentSession,
              let id = workoutExercise?.exerciseId,
              session.activeExerciseIds.count > 1,
              let idx = session.activeExerciseIds.firstIndex(of: id)
        else { return nil }
        return SupersetPosition(
            exerciseIndex: idx,
            totalInRound: session.activeExerciseIds.count,
            isLastInRound: idx == session.activeExerciseIds.count - 1
        )
    }

    private var autoRestAfterSet: Bool {
        guard let pos = supersetPosition else { return true }
        return pos.isLastInRound
    }

    private var effectiveRestAfterSet: Bool {
        restOverride ?? autoRestAfterSet
    }

    /// Keeps weight in range for both typing and the stepper (no negatives, no values above max).
    private var clampedWeightBinding: Binding<Double> {
        Binding(
            get: { weight },
            set: { new in
                guard new.isFinite else { return }
                weight = clampDisplay(new)
            }
        )
    }

    private func clampDisplay(_ w: Double) -> Double {
        WeightStoreConversion.clampNonNegativeDisplay(w, unit: displayUnit)
    }

    private func clampSignedNet(_ w: Double) -> Double {
        WeightStoreConversion.clampSignedNetDisplay(w, unit: displayUnit)
    }

    private var displayNetLoad: Double {
        clampSignedNet(bwAddedDisplay - bwAssistedDisplay)
    }

    private func syncBodyweightFieldsFromNet(_ net: Double) {
        let n = clampSignedNet(net)
        if n >= 0 {
            bwAddedDisplay = clampDisplay(n)
            bwAssistedDisplay = 0
        } else {
            bwAddedDisplay = 0
            bwAssistedDisplay = clampDisplay(-n)
        }
    }

    /// Drop rows with at least one rep; weights converted to stored pounds for persistence.
    private var segmentsForSave: [DropSetSegment] {
        dropRows.compactMap { row in
            guard row.reps > 0 else { return nil }
            let stored = WeightStoreConversion.storedPounds(
                displayValue: clampDisplay(row.weight),
                unit: displayUnit
            )
            return DropSetSegment(weight: stored, reps: row.reps)
        }
    }

    private var dropSetEntryIsValid: Bool {
        !dropSetEnabled || !segmentsForSave.isEmpty
    }

    private func dropWeightBinding(at index: Int) -> Binding<Double> {
        Binding(
            get: {
                guard dropRows.indices.contains(index) else { return 0 }
                return dropRows[index].weight
            },
            set: { new in
                guard dropRows.indices.contains(index) else { return }
                var copy = dropRows
                copy[index].weight = clampDisplay(new)
                dropRows = copy
            }
        )
    }

    private func dropRepsBinding(at index: Int) -> Binding<Int> {
        Binding(
            get: {
                guard dropRows.indices.contains(index) else { return 0 }
                return dropRows[index].reps
            },
            set: { new in
                guard dropRows.indices.contains(index) else { return }
                var copy = dropRows
                copy[index].reps = min(50, max(0, new))
                dropRows = copy
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Log Set") {
                    Toggle("Bodyweight mode (reps first)", isOn: $bodyweightMode)
                        .onChange(of: bodyweightMode) { _, on in
                            if on {
                                if dropSetEnabled {
                                    dropSetEnabled = false
                                    dropRows = []
                                }
                                syncBodyweightFieldsFromNet(weight)
                                weight = 0
                            } else {
                                weight = clampDisplay(max(0, displayNetLoad))
                                bwAddedDisplay = 0
                                bwAssistedDisplay = 0
                            }
                        }

                    if bodyweightMode {
                        Stepper(
                            "Reps: \(reps)",
                            value: $reps,
                            in: 0...50,
                            step: 1
                        )
                        LabeledContent("+ Added") {
                            HStack(spacing: 10) {
                                TextField("0", value: Binding(
                                    get: { bwAddedDisplay },
                                    set: { bwAddedDisplay = clampDisplay($0) }
                                ), format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 56)
                                Text(unitShortLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("− Assisted") {
                            HStack(spacing: 10) {
                                TextField("0", value: Binding(
                                    get: { bwAssistedDisplay },
                                    set: { bwAssistedDisplay = clampDisplay($0) }
                                ), format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 56)
                                Text(unitShortLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if displayNetLoad != 0 {
                            Text(
                                displayNetLoad > 0
                                    ? "Net load: +\(WeightStoreConversion.formatDisplay(displayNetLoad)) \(unitShortLabel)"
                                    : "Net load: −\(WeightStoreConversion.formatDisplay(-displayNetLoad)) \(unitShortLabel) (assisted)"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Text("Net \(unitShortLabel) is saved as 0 (body weight only).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        LabeledContent("Weight") {
                            HStack(spacing: 10) {
                                TextField("0", value: clampedWeightBinding, format: .number.precision(.fractionLength(0...2)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(minWidth: 56)
                                Text(unitShortLabel)
                                    .foregroundStyle(.secondary)
                                Stepper("", value: clampedWeightBinding, in: displayWeightRange, step: weightStep)
                                    .labelsHidden()
                                    .accessibilityLabel("Adjust weight by \(Int(weightStep)) \(unitShortLabel)")
                            }
                        }
                        if weight == 0 {
                            Text("0 \(unitShortLabel) = body weight only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Stepper(
                            "Reps: \(reps)",
                            value: $reps,
                            in: 0...50,
                            step: 1
                        )
                    }

                    if let pos = supersetPosition {
                        HStack {
                            Text("Superset \(pos.exerciseIndex + 1) of \(pos.totalInRound)")
                                .font(.caption.weight(.medium))
                            Spacer()
                            if effectiveRestAfterSet {
                                Label("Rest starts after this set", systemImage: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            } else {
                                Label("No rest \u{2014} next exercise in round", systemImage: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onLongPressGesture {
                            let current = effectiveRestAfterSet
                            restOverride = !current
                            if restOverride == true {
                                restTime = suggestedRestForNextSet()
                            } else {
                                restTime = 0
                            }
                        }
                        if restOverride != nil {
                            HStack {
                                Text("Manual override active")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Spacer()
                                Button("Reset to auto") {
                                    restOverride = nil
                                    restTime = autoRestAfterSet ? suggestedRestForNextSet() : 0
                                }
                                .font(.caption2)
                            }
                        }
                    }

                    if let we = workoutExercise,
                       let suggestion = dataVM.progressionSuggestion(for: we) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Adaptive progression")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(suggestion.shortLine)
                                .font(.caption)
                            Text(suggestion.rationale)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }

                    if effectiveRestAfterSet {
                        Stepper(
                            "Rest after set: \(restTime)s",
                            value: $restTime,
                            in: 0...300,
                            step: 15
                        )
                    }

                    Toggle("Mark as warm-up set", isOn: $isWarmup)

                    Picker("RPE (optional)", selection: $rpeChoice) {
                        Text("None").tag(nil as Int?)
                        ForEach(Array(6...10), id: \.self) { v in
                            Text("\(v)").tag(Optional(v))
                        }
                    }
                }

                Section {
                    Toggle("Drop set", isOn: $dropSetEnabled)
                        .disabled(bodyweightMode)
                    if dropSetEnabled {
                        Text("After your top weight, log each lighter load and reps with no rest in between. Rest below starts when the whole sequence is done.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(dropRows.enumerated()), id: \.element.id) { index, _ in
                            dropRowEditor(at: index)
                        }
                        Button {
                            dropRows.append(EditableDropRow())
                        } label: {
                            Label("Add drop", systemImage: "plus.circle")
                        }
                        if dropSetEnabled && segmentsForSave.isEmpty {
                            Text("Add at least one drop with reps greater than 0, or turn off drop set.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                } header: {
                    Text("Drop set (optional)")
                }

                if let we = workoutExercise, !we.configurationFields.isEmpty {
                    Section("Configuration") {
                        ForEach(we.configurationFields, id: \.self) { field in
                            TextField(field, text: bindingForField(field))
                        }
                    }
                }
            }
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                prefillFromRecentSet()
                if prefillBodyweightMode {
                    bodyweightMode = true
                    if dropSetEnabled {
                        dropSetEnabled = false
                        dropRows = []
                    }
                    let netSeed: Double
                    if let w = prefillDisplayWeight {
                        netSeed = clampSignedNet(w)
                    } else if let session = sessionVM.currentSession,
                              exerciseIndex < session.exerciseLogs.count,
                              let last = session.exerciseLogs[exerciseIndex].loggedSets.last {
                        netSeed = clampSignedNet(
                            WeightStoreConversion.displayValue(storedPounds: last.weight, unit: displayUnit)
                        )
                    } else {
                        netSeed = 0
                    }
                    syncBodyweightFieldsFromNet(netSeed)
                    weight = 0
                } else if let w = prefillDisplayWeight {
                    weight = clampDisplay(w)
                }
                if let r = prefillReps {
                    reps = min(50, max(0, r))
                }
            }

            .onChange(of: dropSetEnabled) { _, on in
                guard !bodyweightMode else { return }
                if on, dropRows.isEmpty {
                    dropRows = [EditableDropRow()]
                }
                if !on {
                    dropRows = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showPlateCalculator = true
                    } label: {
                        Image(systemName: "scalemass")
                    }
                    .accessibilityLabel("Plate calculator")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let effectiveRest = (isSupersetContext && !effectiveRestAfterSet) ? 0 : restTime
                        let displayForStore = bodyweightMode ? displayNetLoad : weight
                        let storedWeight = WeightStoreConversion.storedPounds(
                            displayValue: bodyweightMode ? clampSignedNet(displayForStore) : clampDisplay(displayForStore),
                            unit: displayUnit
                        )
                        sessionVM.logSet(
                            exerciseIndex: exerciseIndex,
                            weight: storedWeight,
                            reps: reps,
                            restTime: effectiveRest,
                            isWarmup: isWarmup,
                            configuration: configValues,
                            dropSegments: (!bodyweightMode && dropSetEnabled) ? segmentsForSave : [],
                            rpe: rpeChoice.map { Double($0) }
                        )

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(reps <= 0 || (!bodyweightMode && !dropSetEntryIsValid))
                }
            }
            .keyboardDismissToolbar()
            .sheet(isPresented: $showPlateCalculator) {
                let suggest: Double? = {
                    if bodyweightMode {
                        let n = displayNetLoad
                        return n > 0 ? n : nil
                    }
                    return weight > 0 ? weight : nil
                }()
                PlateCalculatorSheet(
                    displayUnit: displayUnit,
                    suggestedTargetDisplay: suggest,
                    onApplyDisplayWeight: { w in
                        let c = clampDisplay(w)
                        if bodyweightMode {
                            bwAddedDisplay = c
                            bwAssistedDisplay = 0
                        } else {
                            weight = c
                        }
                    }
                )
            }
        }
    }

    private func prefillFromRecentSet() {
        guard
            let session = sessionVM.currentSession,
            exerciseIndex < session.exerciseLogs.count
        else { return }

        let currentLog = session.exerciseLogs[exerciseIndex]

        // Prefer the most recent set from the current session for this exercise.
        if let lastInSession = currentLog.loggedSets.last {
            weight = clampDisplay(
                WeightStoreConversion.displayValue(storedPounds: lastInSession.weight, unit: displayUnit)
            )
            reps = lastInSession.reps
            restTime = lastInSession.restTime
            // Do not carry warm-up forward: the next set defaults to a normal (working) set.
            isWarmup = false
            if !lastInSession.configuration.isEmpty {
                configValues = lastInSession.configuration
            }
            if !lastInSession.dropSegments.isEmpty {
                dropSetEnabled = true
                dropRows = lastInSession.dropSegments.map {
                    EditableDropRow(
                        weight: clampDisplay(
                            WeightStoreConversion.displayValue(storedPounds: $0.weight, unit: displayUnit)
                        ),
                        reps: $0.reps
                    )
                }
            } else {
                dropSetEnabled = false
                dropRows = []
            }
            if let r = lastInSession.rpe {
                let rounded = Int(r.rounded())
                rpeChoice = (6...10).contains(rounded) ? rounded : nil
            } else {
                rpeChoice = nil
            }
            restOverride = nil
            if isSupersetContext && !autoRestAfterSet {
                restTime = 0
            }
            return
        }

        let targetExerciseId = currentLog.workoutExercise.exerciseId
        guard let targetExerciseId else { return }
        var latestSet: LoggedSet?

        for pastSession in dataVM.completedSessions {
            for log in pastSession.exerciseLogs where log.workoutExercise.exerciseId == targetExerciseId {
                for set in log.loggedSets {
                    if let existing = latestSet {
                        if set.timestamp > existing.timestamp {
                            latestSet = set
                        }
                    } else {
                        latestSet = set
                    }
                }
            }
        }

        if let recent = latestSet {
            weight = clampDisplay(
                WeightStoreConversion.displayValue(storedPounds: recent.weight, unit: displayUnit)
            )
            reps = recent.reps
            restTime = recent.restTime
            isWarmup = false
            if !recent.configuration.isEmpty { configValues = recent.configuration }
            if !recent.dropSegments.isEmpty {
                dropSetEnabled = true
                dropRows = recent.dropSegments.map {
                    EditableDropRow(
                        weight: clampDisplay(
                            WeightStoreConversion.displayValue(storedPounds: $0.weight, unit: displayUnit)
                        ),
                        reps: $0.reps
                    )
                }
            } else {
                dropSetEnabled = false
                dropRows = []
            }
            if let r = recent.rpe {
                let rounded = Int(r.rounded())
                rpeChoice = (6...10).contains(rounded) ? rounded : nil
            } else {
                rpeChoice = nil
            }
        } else {
            restTime = currentLog.workoutExercise.defaultRestTime

            // If there are recommended configuration values for this set index, prefill them.
            if !currentLog.workoutExercise.recommendedConfigBySet.isEmpty {
                let nextIndex = currentLog.loggedSets.count
                if nextIndex < currentLog.workoutExercise.recommendedConfigBySet.count {
                    configValues = currentLog.workoutExercise.recommendedConfigBySet[nextIndex]
                }
            }
            dropSetEnabled = false
            dropRows = []
            rpeChoice = nil
        }

        restOverride = nil
        if isSupersetContext && !autoRestAfterSet {
            restTime = 0
        }
    }

    /// Rest duration for this exercise (matches prefill priority: current session > history > default).
    private func suggestedRestForNextSet() -> Int {
        guard let session = sessionVM.currentSession,
              exerciseIndex < session.exerciseLogs.count
        else { return 90 }

        let currentLog = session.exerciseLogs[exerciseIndex]

        if let last = currentLog.loggedSets.last {
            return last.restTime
        }

        guard let targetExerciseId2 = currentLog.workoutExercise.exerciseId else { return 90 }
        var latestSet: LoggedSet?

        for pastSession in dataVM.completedSessions {
            for log in pastSession.exerciseLogs where log.workoutExercise.exerciseId == targetExerciseId2 {
                for set in log.loggedSets {
                    if let existing = latestSet {
                        if set.timestamp > existing.timestamp {
                            latestSet = set
                        }
                    } else {
                        latestSet = set
                    }
                }
            }
        }

        if let recent = latestSet {
            return recent.restTime
        }

        return currentLog.workoutExercise.defaultRestTime
    }

    @ViewBuilder
    private func dropRowEditor(at index: Int) -> some View {
        if dropRows.indices.contains(index) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Drop \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    if dropRows.count > 1 {
                        Button(role: .destructive) {
                            guard dropRows.indices.contains(index) else { return }
                            dropRows.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.body)
                        }
                    }
                }
                LabeledContent("Weight") {
                    HStack(spacing: 10) {
                        TextField("0", value: dropWeightBinding(at: index), format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 56)
                        Text(unitShortLabel)
                            .foregroundStyle(.secondary)
                        Stepper("", value: dropWeightBinding(at: index), in: displayWeightRange, step: weightStep)
                            .labelsHidden()
                            .accessibilityLabel("Adjust drop weight by \(Int(weightStep)) \(unitShortLabel)")
                    }
                }
                Stepper("Reps: \(dropRows[index].reps)", value: dropRepsBinding(at: index), in: 0...50, step: 1)
            }
            .padding(.vertical, 4)
        }
    }

    private func bindingForField(_ name: String) -> Binding<String> {
        let key = name
        return Binding(
            get: { configValues[key] ?? "" },
            set: { newValue in
                var next = configValues
                next[key] = newValue
                configValues = next
            }
        )
    }
}
