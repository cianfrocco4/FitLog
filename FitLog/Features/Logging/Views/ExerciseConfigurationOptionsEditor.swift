//
//  ExerciseConfigurationOptionsEditor.swift
//  FitLog
//
//  Editor for the per-set setup options of an exercise (grip, seat, attachment).
//

import SwiftUI

/// Machine variants live as setup options on one exercise, so this is where a user defines
/// "Grip: Wide / Medium / Narrow" for their own machines instead of creating near-duplicates.
struct ExerciseConfigurationOptionsEditor: View {
    @Binding var options: [ExerciseConfigurationOption]

    @State private var newChoiceByOptionId: [UUID: String] = [:]

    var body: some View {
        ForEach($options) { $option in
            optionEditor(option: $option)
        }
        .onDelete { offsets in
            options.remove(atOffsets: offsets)
        }

        Button {
            options.append(ExerciseConfigurationOption(name: "", choices: []))
        } label: {
            Label("Add setup option", systemImage: "plus.circle")
        }
        .accessibilityHint("Adds a setting such as grip or seat height that you record with each set")
    }

    @ViewBuilder
    private func optionEditor(option: Binding<ExerciseConfigurationOption>) -> some View {
        let optionId = option.wrappedValue.id
        VStack(alignment: .leading, spacing: 8) {
            TextField("Option name, for example Grip", text: option.name)
                .font(.body.weight(.medium))
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Setup option name")

            if option.wrappedValue.choices.isEmpty {
                Text("No choices yet — this option accepts free text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(option.wrappedValue.choices.enumerated()), id: \.offset) { index, choice in
                    HStack {
                        Text(choice)
                            .font(.subheadline)
                        Spacer(minLength: 8)
                        Button(role: .destructive) {
                            var choices = option.wrappedValue.choices
                            guard choices.indices.contains(index) else { return }
                            choices.remove(at: index)
                            option.wrappedValue.choices = choices
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .frame(minWidth: 44, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Remove choice \(choice)")
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(
                    "Add a choice",
                    text: Binding(
                        get: { newChoiceByOptionId[optionId] ?? "" },
                        set: { newChoiceByOptionId[optionId] = $0 }
                    )
                )
                .textInputAutocapitalization(.words)
                Button("Add") {
                    addChoice(to: option, optionId: optionId)
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 36)
                .disabled(trimmedNewChoice(for: optionId).isEmpty)
                .accessibilityLabel("Add choice to \(option.wrappedValue.name.isEmpty ? "this option" : option.wrappedValue.name)")
            }
        }
        .padding(.vertical, 4)
    }

    private func trimmedNewChoice(for optionId: UUID) -> String {
        (newChoiceByOptionId[optionId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addChoice(to option: Binding<ExerciseConfigurationOption>, optionId: UUID) {
        let choice = trimmedNewChoice(for: optionId)
        guard !choice.isEmpty else { return }
        var choices = option.wrappedValue.choices
        guard !choices.contains(where: { $0.caseInsensitiveCompare(choice) == .orderedSame }) else {
            newChoiceByOptionId[optionId] = ""
            return
        }
        choices.append(choice)
        option.wrappedValue.choices = choices
        newChoiceByOptionId[optionId] = ""
    }
}

#Preview("With options") {
    struct PreviewHost: View {
        @State private var options: [ExerciseConfigurationOption] = [
            ExerciseConfigurationOption(name: "Grip", choices: ["Wide", "Medium", "Narrow"]),
            ExerciseConfigurationOption(name: "Seat", choices: [])
        ]
        var body: some View {
            Form {
                Section("Setup options") {
                    ExerciseConfigurationOptionsEditor(options: $options)
                }
            }
        }
    }
    return PreviewHost()
}

#Preview("Empty — dark") {
    struct PreviewHost: View {
        @State private var options: [ExerciseConfigurationOption] = []
        var body: some View {
            Form {
                Section("Setup options") {
                    ExerciseConfigurationOptionsEditor(options: $options)
                }
            }
        }
    }
    return PreviewHost()
        .preferredColorScheme(.dark)
}
