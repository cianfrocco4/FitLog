//
//  WorkoutExercisePillStrip.swift
//  FitLog
//
//  Horizontal exercise navigation during an active workout with set progress on pills.
//

import SwiftUI

struct WorkoutExercisePillStrip: View {
    let logs: [ExerciseLog]
    @Binding var expandedExerciseIndex: Int?
    let activeExerciseIdsCount: Int
    let displayName: (WorkoutExercise) -> String
    let isExerciseCompleted: (ExerciseLog) -> Bool
    let isExerciseActive: (ExerciseLog) -> Bool
    /// When set (e.g. sheet expanded to `.large`), called after the user picks a pill.
    var onSelectExercise: ((Int) -> Void)? = nil

    var body: some View {
        if logs.count >= 2 {
            VStack(spacing: 4) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                                exercisePill(index: index, log: log)
                                    .id(log.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: expandedExerciseIndex) { _, newIdx in
                        guard let idx = newIdx,
                              idx < logs.count else { return }
                        let targetId = logs[idx].id
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(targetId, anchor: .center)
                        }
                    }
                }
                if activeExerciseIdsCount > 1 {
                    Text("Blue pills = superset. Rest starts after the last exercise in the group.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func exercisePill(index: Int, log: ExerciseLog) -> some View {
        let isSelected = expandedExerciseIndex == index
        let name = abbreviatedName(for: log.workoutExercise)
        let rec = log.workoutExercise.recommendedSets
        let done = log.loggedSets.count
        let isPlaceholder = log.workoutExercise.isSlotPlaceholder
        let isCompleted = isExerciseCompleted(log)
        let inSuperset = isExerciseActive(log)

        Button {
            let newSelection: Int? = isSelected ? nil : index
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedExerciseIndex = newSelection
            }
            if newSelection != nil {
                onSelectExercise?(index)
            }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if isPlaceholder {
                    Image(systemName: "square.dashed")
                        .font(.caption2)
                } else if rec > 0 {
                    Text("\(done)/\(rec)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                } else if done > 0 {
                    Text("\(done)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                }
                if rec > 0 || done > 0 {
                    pillProgressDots(done: done, target: max(rec, done), isSelected: isSelected)
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pillBackground(isSelected: isSelected, inSuperset: inSuperset))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(inSuperset && !isSelected ? Color.blue.opacity(0.55) : Color.clear, lineWidth: 1.5)
            )
            .opacity(isCompleted ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityPillLabel(name: name, done: done, rec: rec, isPlaceholder: isPlaceholder))
        .accessibilityHint(isSelected ? "Double tap to collapse this exercise" : "Double tap to expand and log sets")
        .accessibilityAddTraits(.isButton)
    }

    private func pillProgressDots(done: Int, target: Int, isSelected: Bool) -> some View {
        let n = min(6, max(1, target))
        return HStack(spacing: 2) {
            ForEach(0..<n, id: \.self) { i in
                Circle()
                    .fill(i < done ? (isSelected ? Color.white : Color.accentColor) : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func accessibilityPillLabel(name: String, done: Int, rec: Int, isPlaceholder: Bool) -> String {
        if isPlaceholder { return "\(name), unresolved slot" }
        if rec > 0 { return "\(name), \(done) of \(rec) sets" }
        if done > 0 { return "\(name), \(done) sets logged" }
        return name
    }

    private func abbreviatedName(for we: WorkoutExercise) -> String {
        let full = displayName(we)
        if full.count <= 14 { return full }
        return String(full.prefix(12)) + "…"
    }

    private func pillBackground(isSelected: Bool, inSuperset: Bool) -> Color {
        if isSelected { return Color.accentColor }
        if inSuperset { return Color.blue.opacity(0.12) }
        return Color(.systemGray5)
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var expanded: Int? = 0
        var body: some View {
            WorkoutExercisePillStrip(
                logs: [],
                expandedExerciseIndex: $expanded,
                activeExerciseIdsCount: 1,
                displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" },
                isExerciseCompleted: { _ in false },
                isExerciseActive: { _ in true }
            )
        }
    }
    return PreviewHost()
}
