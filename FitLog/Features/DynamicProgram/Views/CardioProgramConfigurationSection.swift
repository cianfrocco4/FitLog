//
//  CardioProgramConfigurationSection.swift
//  FitLog
//
//  Rich cardio settings for the program builder wizard.
//

import SwiftUI

struct CardioProgramConfigurationSection: View {
    @Binding var splitInput: WorkoutSplitBuilderStructuredInput
    var showPerBlockHint: Bool = false
    var onUserEdited: (() -> Void)? = nil

    private var configuration: CardioProgramConfiguration {
        CardioProgramConfiguration.fromSplitInput(splitInput)
    }

    private var includesCardio: Bool {
        configuration.preference != .none
    }

    var body: some View {
        Group {
            Picker("Cardio goal", selection: cardioGoalBinding) {
                ForEach(CardioProgramGoal.allCases) { goal in
                    Text(goal.rawValue).tag(goal.rawValue)
                }
            }
            .onChange(of: splitInput.cardioGoal) { _, newValue in
                let goal = CardioProgramGoal.fromStored(newValue)
                if CardioProgramPreference.fromStored(splitInput.cardioPreference) == .none,
                   goal != .generalHealth {
                    splitInput.cardioPreference = goal.defaultPreference.rawValue
                }
            }

            Picker("Cardio in program", selection: cardioPreferenceBinding) {
                ForEach(CardioProgramPreference.allCases) { preference in
                    Text(preference.rawValue).tag(preference.rawValue)
                }
            }
            .onChange(of: splitInput.cardioPreference) { _, _ in
                onUserEdited?()
            }

            if includesCardio {
                if configuration.preference.includesDedicatedCardioDays {
                    Stepper(value: dedicatedDayCountBinding, in: 1 ... 4) {
                        Text("Dedicated cardio days: \(configuration.dedicatedDayCount)")
                    }
                    .accessibilityLabel("Dedicated cardio days per week")
                }

                if configuration.preference.includesPostWorkoutFinishers {
                    Picker("Finisher length", selection: finisherDurationBinding) {
                        ForEach([5, 10, 15, 20], id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                    Picker("Finisher intensity", selection: finisherZoneBinding) {
                        ForEach(CardioIntensityZone.allCases) { zone in
                            Text(zone.displayName).tag(zone.rawValue)
                        }
                    }
                }

                Stepper(value: weeklyProgressionBinding, in: 0 ... 15) {
                    Text("Weekly cardio progression: +\(configuration.weeklyProgressionMinutes) min/wk")
                }
                .accessibilityLabel("Weekly cardio progression minutes")

                Text("Estimated cardio: ~\(configuration.estimatedWeeklyMinutes) min/week")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showPerBlockHint {
                    Text("Customize cardio per phase in “Your phases” when phase customization is enabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var cardioGoalBinding: Binding<String> {
        Binding(get: { splitInput.cardioGoal }, set: { splitInput.cardioGoal = $0 })
    }

    private var cardioPreferenceBinding: Binding<String> {
        Binding(get: { splitInput.cardioPreference }, set: { splitInput.cardioPreference = $0 })
    }

    private var dedicatedDayCountBinding: Binding<Int> {
        Binding(
            get: { splitInput.cardioDedicatedDayCount ?? 2 },
            set: { splitInput.cardioDedicatedDayCount = $0 }
        )
    }

    private var finisherDurationBinding: Binding<Int> {
        Binding(
            get: { splitInput.cardioFinisherDurationMinutes ?? 10 },
            set: { splitInput.cardioFinisherDurationMinutes = $0 }
        )
    }

    private var finisherZoneBinding: Binding<Int> {
        Binding(
            get: { splitInput.cardioFinisherZoneRaw ?? CardioIntensityZone.zone2.rawValue },
            set: { splitInput.cardioFinisherZoneRaw = $0 }
        )
    }

    private var weeklyProgressionBinding: Binding<Int> {
        Binding(
            get: { splitInput.cardioWeeklyProgressionMinutes ?? 5 },
            set: { splitInput.cardioWeeklyProgressionMinutes = $0 }
        )
    }
}

struct BlockCardioOverrideSection: View {
    @Binding var spec: DynamicBlockGenerationSpec
    let inheritLabel: String

    var body: some View {
        Picker("Cardio for this phase", selection: blockCardioPreferenceBinding) {
            Text("Same as program — \(inheritLabel)").tag("")
            ForEach(CardioProgramPreference.allCases) { preference in
                Text(preference.rawValue).tag(preference.rawValue)
            }
        }

        if spec.cardioPreference != nil || spec.cardioGoal != nil {
            Picker("Phase cardio goal", selection: blockCardioGoalBinding) {
                Text("Same as program").tag("")
                ForEach(CardioProgramGoal.allCases) { goal in
                    Text(goal.rawValue).tag(goal.rawValue)
                }
            }

            if spec.cardioPreference?.includesDedicatedCardioDays == true {
                Stepper(value: blockDedicatedDaysBinding, in: 1 ... 4) {
                    Text("Dedicated days: \(spec.cardioDedicatedDayCount ?? 2)")
                }
            }
        }
    }

    private var blockCardioPreferenceBinding: Binding<String> {
        Binding(
            get: { spec.cardioPreference?.rawValue ?? "" },
            set: { raw in
                spec.cardioPreference = raw.isEmpty ? nil : CardioProgramPreference(rawValue: raw)
            }
        )
    }

    private var blockCardioGoalBinding: Binding<String> {
        Binding(
            get: { spec.cardioGoal?.rawValue ?? "" },
            set: { raw in
                spec.cardioGoal = raw.isEmpty ? nil : CardioProgramGoal(rawValue: raw)
            }
        )
    }

    private var blockDedicatedDaysBinding: Binding<Int> {
        Binding(
            get: { spec.cardioDedicatedDayCount ?? 2 },
            set: { spec.cardioDedicatedDayCount = $0 }
        )
    }
}
