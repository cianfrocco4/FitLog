//
//  CoachPlanPreviewView.swift
//  FitLog
//
//  Editable plan preview for Guided Coach (replaces Accept cards + read-only summary).
//

import SwiftUI

struct CoachPlanPreviewView: View {
    let blueprint: CoachBlueprint
    @Binding var scheduleSessions: Int
    @Binding var weekdays: Set<Int>
    @Binding var finalNotes: String
    let autoUpdates: [CoachRecommendationChange]
    let isLoading: Bool
    let requiresPremium: Bool
    let onUpdateRecommendation: (CoachRecommendationTopic, String) -> Void
    let onUpdateSchedule: (Int, Set<Int>) -> Void
    let onDiscuss: (CoachRecommendationTopic) -> Void
    let onBuild: () -> Void

    @State private var programNameDraft: String = ""
    @State private var showTrainingStyle = false
    @State private var expandedWhy: Set<CoachRecommendationTopic> = []
    @FocusState private var isFinalNotesFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your program plan")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("Edit anything below. You’re in control — then build when it looks right.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            nameRow
            scheduleRow
            editableMenuRow(
                topic: .split,
                title: "Split style",
                systemImage: "calendar",
                current: blueprint.splitPreference,
                options: CoachSplitPick.allCases.map(\.rawValue)
            )
            if blueprint.usedSavedSplitPreference {
                Text("Using your saved split preference")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 44)
            }
            editableMenuRow(
                topic: .programLength,
                title: "Program length",
                systemImage: "clock",
                current: "\(blueprint.totalWeeks) weeks",
                options: CoachProgramLengthPick.allCases.map(\.label)
            )
            editableMenuRow(
                topic: .cardio,
                title: "Cardio plan",
                systemImage: "figure.run",
                current: cardioCurrent,
                options: CoachCardioPick.allCases.map(\.rawValue)
            )
            editableMenuRow(
                topic: .periodization,
                title: "Training phases",
                systemImage: "chart.line.uptrend.xyaxis",
                current: periodizationCurrent,
                options: [
                    "One continuous phase",
                    "Two phases — build, then peak",
                    "Three phases — build, peak, recover",
                ]
            )

            DisclosureGroup(isExpanded: $showTrainingStyle) {
                VStack(alignment: .leading, spacing: 12) {
                    editableMenuRow(
                        topic: .intensity,
                        title: "Intensity style",
                        systemImage: "bolt.fill",
                        current: blueprint.intensityStyle,
                        options: uniqueOptions(
                            CoachIntensityPick.allCases.map(\.rawValue),
                            including: blueprint.intensityStyle
                        )
                    )
                    editableMenuRow(
                        topic: .progression,
                        title: "Progression style",
                        systemImage: "arrow.up.forward",
                        current: blueprint.progressionStyle,
                        options: uniqueOptions(
                            CoachProgressionPick.allCases.map(\.rawValue),
                            including: blueprint.progressionStyle
                        )
                    )
                    editableMenuRow(
                        topic: .deload,
                        title: "Deload approach",
                        systemImage: "leaf.fill",
                        current: blueprint.deloadPreference,
                        options: uniqueOptions(
                            CoachDeloadPick.allCases.map(\.rawValue),
                            including: blueprint.deloadPreference
                        )
                    )
                }
                .padding(.top, 8)
            } label: {
                Label("Training style", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityHint("Show intensity, progression, and deload options")

            if !autoUpdates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Updated for your schedule")
                        .font(.subheadline.weight(.semibold))
                    ForEach(autoUpdates) { change in
                        Label("\(change.topic.title) → \(change.afterValue)", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !blueprint.changes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Changes you made")
                        .font(.subheadline.weight(.semibold))
                    ForEach(blueprint.changes) { change in
                        Label(change.diffDescription, systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !dedupedWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(.subheadline.weight(.semibold))
                    ForEach(dedupedWarnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(FitlogPalette.caution)
                    }
                }
            }

            blockTimeline

            VStack(alignment: .leading, spacing: 6) {
                Text("Final notes (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Anything else before we build?", text: $finalNotes, axis: .vertical)
                    .lineLimit(2 ... 4)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFinalNotesFocused)
                    .accessibilityLabel("Final notes")
                    .accessibilityHint("Optional notes before building. Tap Done to dismiss the keyboard.")
            }

            Button {
                isFinalNotesFocused = false
                fitlogDismissKeyboard()
                onBuild()
            } label: {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Building your program…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 2) {
                        Text("Build My Program")
                            .frame(maxWidth: .infinity)
                        if requiresPremium {
                            Text("Premium")
                                .font(.caption2.weight(.semibold))
                                .opacity(0.9)
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .accessibilityLabel(isLoading ? "Building your program" : "Build my program")
            .accessibilityHint(
                requiresPremium
                    ? "Requires Premium to generate with AI"
                    : "Generate your training program from this plan"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitlogPalette.subtleFill)
        )
        .onAppear {
            programNameDraft = blueprint.programName
            scheduleSessions = blueprint.sessionsPerWeek
            weekdays = Set(blueprint.preferredWeekdays)
        }
        .onChange(of: blueprint.programName) { _, newValue in
            if programNameDraft != newValue {
                programNameDraft = newValue
            }
        }
    }

    // MARK: - Rows

    private var nameRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "textformat")
                    .foregroundStyle(FitlogPalette.chartPrimary)
                    .frame(width: 28)
                Text("Program name")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                discussButton(for: .programName)
            }
            TextField("Program name", text: $programNameDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Program name")
                .accessibilityHint("Edit the name of your program")
                .onSubmit { commitName() }
                .onChange(of: programNameDraft) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        let fallback = blueprint.recommendation(for: .programName)?.recommendedValue ?? blueprint.programName
                        onUpdateRecommendation(.programName, fallback)
                    } else if trimmed != blueprint.programName {
                        onUpdateRecommendation(.programName, trimmed)
                    }
                }
            whySection(for: .programName)
        }
    }

    private var scheduleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(FitlogPalette.chartPrimary)
                    .frame(width: 28)
                Text("Schedule")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            Stepper(
                value: Binding(
                    get: { CoachScheduleSync.clampSessions(scheduleSessions, to: weekdays) },
                    set: { newValue in
                        let clamped = CoachScheduleSync.clampSessions(newValue, to: weekdays)
                        scheduleSessions = clamped
                        onUpdateSchedule(clamped, weekdays)
                    }
                ),
                in: 1 ... CoachScheduleSync.maxSessions(for: weekdays)
            ) {
                Text("Sessions per week: \(CoachScheduleSync.clampSessions(scheduleSessions, to: weekdays))")
            }
            .accessibilityLabel("Sessions per week")

            Text("Preferred days (optional)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(CoachScheduleSync.orderedWeekdayNumbers(), id: \.self) { day in
                    let selected = weekdays.contains(day)
                    let symbol = CoachScheduleSync.shortSymbol(for: day)
                    Button {
                        let result = CoachScheduleSync.toggleWeekday(day, sessions: scheduleSessions, weekdays: weekdays)
                        weekdays = result.weekdays
                        scheduleSessions = result.sessions
                        onUpdateSchedule(result.sessions, result.weekdays)
                    } label: {
                        Text(String(symbol.prefix(1)))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(symbol), \(selected ? "selected" : "not selected")")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func editableMenuRow(
        topic: CoachRecommendationTopic,
        title: String,
        systemImage: String,
        current: String,
        options: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(FitlogPalette.chartPrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let coach = blueprint.recommendation(for: topic)?.recommendedValue,
                       coach != current {
                        Text("Coach suggested: \(coach)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 8)
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) {
                            onUpdateRecommendation(topic, option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(current)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel("\(title), \(current)")
                .accessibilityHint("Change \(title.lowercased())")

                discussButton(for: topic)
            }
            whySection(for: topic)
        }
    }

    @ViewBuilder
    private func whySection(for topic: CoachRecommendationTopic) -> some View {
        let rationale = trimmedRationale(for: topic)
        if !rationale.isEmpty {
            let isLong = rationale.count > 120 || rationale.contains("\n")
            let isExpanded = expandedWhy.contains(topic)

            // Only clamp text that also gets a Show more control, so nothing can be
            // truncated without an affordance at large Dynamic Type sizes.
            Text(rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(isLong && !isExpanded ? 2 : nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 38)
                .accessibilityLabel("Why this: \(rationale)")

            if isLong {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedWhy.remove(topic)
                        } else {
                            expandedWhy.insert(topic)
                        }
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.leading, 38)
                .accessibilityHint(isExpanded ? "Collapse coach rationale" : "Expand full coach rationale for \(topic.title)")
            }
        }
    }

    private func trimmedRationale(for topic: CoachRecommendationTopic) -> String {
        (blueprint.recommendation(for: topic)?.rationale ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dedupedWarnings: [String] {
        CoachRecommendationEngine.dedupeWarnings(blueprint.warnings)
    }

    private func discussButton(for topic: CoachRecommendationTopic) -> some View {
        Button {
            onDiscuss(topic)
        } label: {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Discuss \(topic.title)")
        .accessibilityHint("Ask the coach about this recommendation")
    }

    private var cardioCurrent: String {
        if let pick = CoachCardioPick.allCases.first(where: { $0.preference == blueprint.cardioConfiguration.preference }) {
            return pick.rawValue
        }
        return blueprint.recommendation(for: .cardio)?.finalValue
            ?? blueprint.cardioConfiguration.preference.rawValue
    }

    private var periodizationCurrent: String {
        if let final = blueprint.recommendation(for: .periodization)?.finalValue {
            if final.lowercased().contains("three") {
                return "Three phases — build, peak, recover"
            }
            if final.lowercased().contains("two") {
                return "Two phases — build, then peak"
            }
            if final.lowercased().contains("one") || final.lowercased().contains("continuous") {
                return "One continuous phase"
            }
            return final
        }
        return blueprint.isPeriodized
            ? (blueprint.blockSpecs.count >= 3
                ? "Three phases — build, peak, recover"
                : "Two phases — build, then peak")
            : "One continuous phase"
    }

    private var blockTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(blueprint.blockSpecs.indices, id: \.self) { index in
                        let block = blueprint.blockSpecs[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                            Text("\(block.durationWeeks) wk")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(block.focus.displayTitle)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .frame(width: 120, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.opacity(index == 0 ? 0.12 : 0.06))
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Program timeline")
    }

    private func commitName() {
        let trimmed = programNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onUpdateRecommendation(.programName, trimmed)
    }

    private func uniqueOptions(_ base: [String], including current: String) -> [String] {
        var opts = base
        if !opts.contains(current) {
            opts.insert(current, at: 0)
        }
        return opts
    }
}

#Preview("Light") {
    ScrollView {
        CoachPlanPreviewView(
            blueprint: CoachRecommendationEngine.buildBlueprint(from: CoachIntakeSnapshot(
                primaryGoal: CoachGoalPick.buildMuscle.rawValue,
                experienceLevel: CoachExperiencePick.intermediate.rawValue,
                sessionsPerWeek: 4,
                sessionDurationMinutes: 60
            )),
            scheduleSessions: .constant(4),
            weekdays: .constant([2, 4, 5, 6]),
            finalNotes: .constant(""),
            autoUpdates: [],
            isLoading: false,
            requiresPremium: true,
            onUpdateRecommendation: { _, _ in },
            onUpdateSchedule: { _, _ in },
            onDiscuss: { _ in },
            onBuild: {}
        )
        .padding()
    }
}

#Preview("Dark XXL") {
    ScrollView {
        CoachPlanPreviewView(
            blueprint: {
                var bp = CoachRecommendationEngine.buildBlueprint(from: CoachIntakeSnapshot(
                    primaryGoal: CoachGoalPick.fatLoss.rawValue,
                    experienceLevel: CoachExperiencePick.beginner.rawValue,
                    sessionsPerWeek: 5,
                    limitationsNotes: "Knee discomfort"
                ))
                _ = CoachRecommendationEngine.applyRecommendationChange(
                    to: &bp,
                    topic: .programName,
                    newValue: "Cut Season"
                )
                return bp
            }(),
            scheduleSessions: .constant(5),
            weekdays: .constant([]),
            finalNotes: .constant("Prefer morning sessions"),
            autoUpdates: [],
            isLoading: false,
            requiresPremium: true,
            onUpdateRecommendation: { _, _ in },
            onUpdateSchedule: { _, _ in },
            onDiscuss: { _ in },
            onBuild: {}
        )
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
    .preferredColorScheme(.dark)
}
