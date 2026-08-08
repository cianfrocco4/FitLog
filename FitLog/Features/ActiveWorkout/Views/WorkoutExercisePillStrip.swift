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
    let supersetLetter: (ExerciseLog) -> String?
    var onSelectExercise: ((Int) -> Void)? = nil
    var onAddExercise: (() -> Void)? = nil
    var onQuickSwap: ((Int) -> Void)? = nil
    var onToggleSuperset: ((Int) -> Void)? = nil
    var onMarkCompleted: ((Int) -> Void)? = nil
    var onRemoveExercise: ((Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 4) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                            exercisePill(index: index, log: log)
                                .id(log.id)
                        }
                        if let onAddExercise {
                            Button(action: onAddExercise) {
                                Label("Add", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add exercise")
                            .accessibilityHint("Opens the exercise picker")
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
                Text("Blue outline = superset round. Rest after the last letter in the group.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func exercisePill(index: Int, log: ExerciseLog) -> some View {
        let isSelected = expandedExerciseIndex == index
        let name = abbreviatedName(for: log.workoutExercise)
        let rec = log.workoutExercise.recommendedSets
        let done = log.loggedSets.count
        let isPlaceholder = log.workoutExercise.isSlotPlaceholder
        let isCompleted = isExerciseCompleted(log)
        let inSuperset = isExerciseActive(log) && activeExerciseIdsCount > 1
        let letter = supersetLetter(log)

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedExerciseIndex = index
            }
            onSelectExercise?(index)
        } label: {
            HStack(spacing: 4) {
                if let letter {
                    Text(letter)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.blue)
                        .frame(minWidth: 16)
                }
                Text(name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if isPlaceholder {
                    Image(systemName: "square.dashed")
                        .font(.caption2)
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.green)
                } else if rec > 0 {
                    Text("\(done)/\(rec)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                } else if done > 0 {
                    Text("\(done)")
                        .font(.caption2.weight(.medium))
                        .monospacedDigit()
                }
                if !isCompleted, rec > 0 || done > 0 {
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
            .opacity(isCompleted && !isSelected ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if log.workoutExercise.exerciseId != nil, let onQuickSwap {
                Button("Quick swap", systemImage: "arrow.left.arrow.right") { onQuickSwap(index) }
            }
            if log.workoutExercise.exerciseId != nil, let onToggleSuperset {
                Button(
                    inSuperset ? "Remove from superset" : "Add to superset",
                    systemImage: "bolt.horizontal"
                ) { onToggleSuperset(index) }
            }
            if log.workoutExercise.exerciseId != nil, !isCompleted, let onMarkCompleted {
                Button("Mark done", systemImage: "checkmark.circle") { onMarkCompleted(index) }
            }
            if let onRemoveExercise {
                Button("Remove", systemImage: "trash", role: .destructive) { onRemoveExercise(index) }
            }
        }
        .accessibilityLabel(accessibilityPillLabel(name: name, done: done, rec: rec, isPlaceholder: isPlaceholder, letter: letter))
        .accessibilityHint(isSelected ? "Currently selected exercise" : "Double tap to log sets for this exercise")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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

    private func accessibilityPillLabel(name: String, done: Int, rec: Int, isPlaceholder: Bool, letter: String?) -> String {
        var parts: [String] = []
        if let letter { parts.append("Superset \(letter)") }
        parts.append(name)
        if isPlaceholder { parts.append("needs an exercise") }
        else if rec > 0 { parts.append("\(done) of \(rec) sets") }
        else if done > 0 { parts.append("\(done) sets logged") }
        return parts.joined(separator: ", ")
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
                activeExerciseIdsCount: 2,
                displayName: { $0.snapshot?.nameAtTimeOfLog ?? "Exercise" },
                isExerciseCompleted: { _ in false },
                isExerciseActive: { _ in true },
                supersetLetter: { _ in "A" },
                onAddExercise: {}
            )
        }
    }
    return PreviewHost()
}
