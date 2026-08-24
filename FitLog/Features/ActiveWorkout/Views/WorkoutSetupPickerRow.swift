//
//  WorkoutSetupPickerRow.swift
//  FitLog
//
//  Compact per-set setup picker (grip, seat, attachment) for the active workout sheet.
//

import SwiftUI

struct WorkoutSetupPickerRow: View {
    let fields: [ExerciseSetupField]
    let values: [String: String]
    let onSelect: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label("Setup", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text("Applies to your next set")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(fields) { field in
                        setupControl(for: field)
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Setup for the next set")
    }

    @ViewBuilder
    private func setupControl(for field: ExerciseSetupField) -> some View {
        let value = values[field.name] ?? ""
        if field.choices.isEmpty {
            freeformField(field: field, value: value)
        } else {
            Menu {
                Picker(field.name, selection: selectionBinding(for: field)) {
                    Text("Not set").tag("")
                    ForEach(field.choices, id: \.self) { choice in
                        Text(choice).tag(choice)
                    }
                }
            } label: {
                chipLabel(name: field.name, value: value, showsChevron: true)
            }
            .accessibilityLabel(accessibilityLabel(field: field, value: value))
            .accessibilityHint("Chooses the \(field.name.lowercased()) recorded with your next set")
        }
    }

    private func freeformField(field: ExerciseSetupField, value: String) -> some View {
        HStack(spacing: 6) {
            Text(field.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(field.name, text: selectionBinding(for: field))
                .font(.caption.weight(.medium))
                .textFieldStyle(.plain)
                .frame(minWidth: 56)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(Color(.systemGray6), in: Capsule())
        .accessibilityLabel(accessibilityLabel(field: field, value: value))
    }

    private func chipLabel(name: String, value: String, showsChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Set" : value)
                .font(.caption.weight(.medium))
                .foregroundStyle(value.isEmpty ? Color.accentColor : Color.primary)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(Color(.systemGray6), in: Capsule())
        .contentShape(Capsule())
    }

    private func selectionBinding(for field: ExerciseSetupField) -> Binding<String> {
        Binding(
            get: { values[field.name] ?? "" },
            set: { onSelect(field.name, $0) }
        )
    }

    private func accessibilityLabel(field: ExerciseSetupField, value: String) -> String {
        value.isEmpty ? "\(field.name), not set" : "\(field.name), \(value)"
    }
}

#Preview("Choices and free-form") {
    WorkoutSetupPickerRow(
        fields: [
            ExerciseSetupField(name: "Grip", choices: ["Wide", "Medium", "Narrow"]),
            ExerciseSetupField(name: "Seat", choices: [])
        ],
        values: ["Grip": "Wide"],
        onSelect: { _, _ in }
    )
    .padding()
}

#Preview("Nothing set — dark") {
    WorkoutSetupPickerRow(
        fields: [ExerciseSetupField(name: "Grip", choices: ["Wide", "Medium", "Narrow"])],
        values: [:],
        onSelect: { _, _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
