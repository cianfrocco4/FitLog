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
    @Environment(\.dismiss) var dismiss

    let exerciseIndex: Int

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

    private static let weightRange: ClosedRange<Double> = 0...1100

    /// Keeps weight in range for both typing and the stepper (no negatives, no values above max).
    private var clampedWeightBinding: Binding<Double> {
        Binding(
            get: { weight },
            set: { new in
                guard new.isFinite else { return }
                weight = Self.clampWeight(new)
            }
        )
    }

    private static func clampWeight(_ w: Double) -> Double {
        guard w.isFinite else { return 0 }
        return min(weightRange.upperBound, max(weightRange.lowerBound, w))
    }

    /// Drop rows with at least one rep (weights clamped on save).
    private var sanitizedDropSegments: [DropSetSegment] {
        dropRows.compactMap { row in
            guard row.reps > 0 else { return nil }
            return DropSetSegment(weight: Self.clampWeight(row.weight), reps: row.reps)
        }
    }

    private var dropSetEntryIsValid: Bool {
        !dropSetEnabled || !sanitizedDropSegments.isEmpty
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
                copy[index].weight = Self.clampWeight(new)
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
                    LabeledContent("Weight") {
                        HStack(spacing: 10) {
                            TextField("0", value: clampedWeightBinding, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 56)
                            Text("lb")
                                .foregroundStyle(.secondary)
                            Stepper("", value: clampedWeightBinding, in: Self.weightRange, step: 5)
                                .labelsHidden()
                                .accessibilityLabel("Adjust weight by 5 pounds")
                        }
                    }
                    if weight == 0 {
                        Text("0 lb = body weight only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Stepper(
                        "Reps: \(reps)",
                        value: $reps,
                        in: 0...50,
                        step: 1
                    )

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

                    if effectiveRestAfterSet {
                        Stepper(
                            "Rest after set: \(restTime)s",
                            value: $restTime,
                            in: 0...300,
                            step: 15
                        )
                    }

                    Toggle("Mark as warm-up set", isOn: $isWarmup)
                }

                Section {
                    Toggle("Drop set", isOn: $dropSetEnabled)
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
                        if dropSetEnabled && sanitizedDropSegments.isEmpty {
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
            }
            
            .onChange(of: dropSetEnabled) { _, on in
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
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let effectiveRest = (isSupersetContext && !effectiveRestAfterSet) ? 0 : restTime
                        sessionVM.logSet(
                            exerciseIndex: exerciseIndex,
                            weight: weight,
                            reps: reps,
                            restTime: effectiveRest,
                            isWarmup: isWarmup,
                            configuration: configValues,
                            dropSegments: dropSetEnabled ? sanitizedDropSegments : []
                        )

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(reps <= 0 || !dropSetEntryIsValid)
                }
            }
            .keyboardDismissToolbar()
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
            weight = Self.clampWeight(lastInSession.weight)
            reps = lastInSession.reps
            restTime = lastInSession.restTime
            isWarmup = lastInSession.isWarmup
            if !lastInSession.configuration.isEmpty {
                configValues = lastInSession.configuration
            }
            if !lastInSession.dropSegments.isEmpty {
                dropSetEnabled = true
                dropRows = lastInSession.dropSegments.map { EditableDropRow(weight: $0.weight, reps: $0.reps) }
            } else {
                dropSetEnabled = false
                dropRows = []
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
            weight = Self.clampWeight(recent.weight)
            reps = recent.reps
            restTime = recent.restTime
            isWarmup = recent.isWarmup
            if !recent.configuration.isEmpty { configValues = recent.configuration }
            if !recent.dropSegments.isEmpty {
                dropSetEnabled = true
                dropRows = recent.dropSegments.map { EditableDropRow(weight: $0.weight, reps: $0.reps) }
            } else {
                dropSetEnabled = false
                dropRows = []
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
                        Text("lb")
                            .foregroundStyle(.secondary)
                        Stepper("", value: dropWeightBinding(at: index), in: Self.weightRange, step: 5)
                            .labelsHidden()
                            .accessibilityLabel("Adjust drop weight by 5 pounds")
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
