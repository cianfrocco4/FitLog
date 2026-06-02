//
//  WorkoutQuickSetTypeBar.swift
//  FitLog
//
//  Horizontal set-type chips for fast inline logging (gym-sized targets).
//

import SwiftUI

struct WorkoutQuickSetTypeBar: View {
    @Binding var selection: ExerciseSetType
    /// Drop sets require an existing logged set on this exercise.
    var dropSetEnabled: Bool = true

    private let types: [ExerciseSetType] = [.working, .warmup, .dropSet, .amrap, .failure, .timed]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.self) { type in
                    let isOn = selection == type
                    let isDropDisabled = type == .dropSet && !dropSetEnabled
                    Button {
                        guard !isDropDisabled else { return }
                        selection = type
                    } label: {
                        Text(shortLabel(type))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(isOn ? Color.accentColor.opacity(0.22) : Color(.systemGray5))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(isOn ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isDropDisabled ? Color.secondary.opacity(0.45) : (isOn ? Color.accentColor : Color.primary))
                    .disabled(isDropDisabled)
                    .accessibilityLabel("Set type \(type.logPickerLabel)")
                    .accessibilityHint(
                        isDropDisabled
                            ? "Log a working set first to add drop segments"
                            : (isOn ? "Selected" : "Double tap to select")
                    )
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func shortLabel(_ type: ExerciseSetType) -> String {
        switch type {
        case .working: return "Work"
        case .warmup: return "Warm"
        case .amrap: return "AMRAP"
        case .failure: return "Fail"
        case .timed: return "Time"
        case .dropSet: return "Drop"
        case .intervalWork: return "Int"
        case .intervalRest: return "Rest"
        case .steadyState: return "Steady"
        }
    }
}

#Preview {
    struct Host: View {
        @State private var sel = ExerciseSetType.working
        var body: some View {
            WorkoutQuickSetTypeBar(selection: $sel)
                .padding()
        }
    }
    return Host()
}
