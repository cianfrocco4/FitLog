//
//  AISplitBuilderView.swift
//  FitLog
//
//  Wizard + preview for AI-generated workout splits (Chat Completions JSON).
//

import SwiftUI

private enum SplitBuilderLimits {
    static let maxComposedContextChars = 600
    static let maxOptionalFieldChars = 220
}

private enum PrimaryTrainingGoal: String, CaseIterable, Identifiable {
    case buildMuscle = "Build muscle & size"
    case strength = "Get stronger (strength focus)"
    case fatLoss = "Fat loss / conditioning"
    case general = "General fitness & health"
    case performance = "Athletic / sport performance"

    var id: String { rawValue }
}

private enum EquipmentAccess: String, CaseIterable, Identifiable {
    case fullGym = "Full gym (machines + free weights)"
    case homeFreeWeights = "Home — barbell, dumbbells, bench"
    case dumbbellsOnly = "Home — dumbbells only"
    case bodyweight = "Mostly bodyweight"
    case minimal = "Very limited equipment"

    var id: String { rawValue }
}

private enum SplitStylePreference: String, CaseIterable, Identifiable {
    case noPreference = "No preference — you decide"
    case pushPullLegs = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case fullBody = "Full body"
    case broSplit = "Muscle group (bro) split"

    var id: String { rawValue }
}

private enum ExperiencePick: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

struct AISplitBuilderView: View {
    @EnvironmentObject private var dataVM: DataManager
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var primaryGoal: PrimaryTrainingGoal = .general
    @State private var equipment: EquipmentAccess = .fullGym
    @State private var splitPreference: SplitStylePreference = .noPreference
    @State private var definitionPreference: WorkoutSplitDefinitionPreference = .concreteLists
    @State private var experience: ExperiencePick = .intermediate
    @State private var limitationsNotes = ""
    @State private var additionalNotes = ""

    @State private var sessionsPerWeek = 3
    @State private var selectedWeekdays: Set<Int> = []
    @State private var updateTrainingProgram = true

    @State private var proposal: WorkoutSplitProposal?
    @State private var isGenerating = false
    @State private var isApplying = false
    @State private var errorBanner: String?

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            Group {
                if let p = proposal {
                    previewContent(p)
                } else {
                    formContent
                }
            }
            .navigationTitle(proposal == nil ? "AI split builder" : "Preview split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var formContent: some View {
        Form {
            if !aiService.isConfigured {
                Section {
                    notConfiguredBanner
                }
            }

            Section {
                Picker("Main goal", selection: $primaryGoal) {
                    ForEach(PrimaryTrainingGoal.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
                Picker("Equipment you have", selection: $equipment) {
                    ForEach(EquipmentAccess.allCases) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                Picker("Split style", selection: $splitPreference) {
                    ForEach(SplitStylePreference.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                Picker("Day definition", selection: $definitionPreference) {
                    ForEach(WorkoutSplitDefinitionPreference.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                Picker("Experience level", selection: $experience) {
                    ForEach(ExperiencePick.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            } header: {
                Text("Your training")
            } footer: {
                Text("Day definition controls whether the AI outputs fixed exercise lists, open slots (muscle + optional exercise hint), or a mix. These answers are sent to the coach to shape your split.")
            }

            Section {
                Stepper("Sessions per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...7)
                Text("Preferred training days (optional). Leave none selected to use the app default Mon–Fri pool.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                weekdayMultiSelect
            } header: {
                Text("Availability")
            }

            Section {
                TextField("Injuries or movements to avoid (optional)", text: $limitationsNotes, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Anything else we should know? (optional)", text: $additionalNotes, axis: .vertical)
                    .lineLimit(2...4)
                Text("Up to \(SplitBuilderLimits.maxOptionalFieldChars) characters in each optional field.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Optional details")
            } footer: {
                Text("Examples: bad shoulder, no overhead pressing, prefer short workouts.")
            }

            Section {
                Toggle("Set as my training program", isOn: $updateTrainingProgram)
                Text("When on, your Plan cycle and weekly schedule update to this split. When off, only new workout templates are created.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await generate() }
                } label: {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generating…")
                        }
                    } else {
                        Label("Generate split", systemImage: "sparkles")
                    }
                }
                .disabled(!aiService.isConfigured || isGenerating)
            }

            if let err = errorBanner {
                Section {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .onChange(of: limitationsNotes) { _, new in
            if new.count > SplitBuilderLimits.maxOptionalFieldChars {
                limitationsNotes = String(new.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            }
        }
        .onChange(of: additionalNotes) { _, new in
            if new.count > SplitBuilderLimits.maxOptionalFieldChars {
                additionalNotes = String(new.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            }
        }
        .keyboardDismissToolbar()
    }

    private func previewContent(_ p: WorkoutSplitProposal) -> some View {
        let resolution = resolveProposal(p)
        return List {
            Section {
                Text(p.rationale)
                    .font(.subheadline)
                LabeledContent("Sessions / week", value: "\(p.sessionsPerWeek)")
                if p.preferredWeekdays.isEmpty {
                    LabeledContent("Preferred days", value: "Default (Mon–Fri pool)")
                } else {
                    LabeledContent("Preferred days", value: p.preferredWeekdays.map { weekdayLabel($0) }.joined(separator: ", "))
                }
            } header: {
                Text("Summary")
            }

            if !resolution.unresolvedExerciseNames.isEmpty {
                Section {
                    Text("These names were not found in your library and will be skipped when applying: \(resolution.unresolvedExerciseNames.sorted().joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } header: {
                    Text("Unmatched names")
                }
            }

            ForEach(Array(p.workouts.enumerated()), id: \.offset) { _, day in
                Section {
                    if let focus = day.focus, !focus.isEmpty {
                        Text(focus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if day.isSlotTemplateDay {
                        Label("Slot template", systemImage: "square.grid.3x3.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(day.slots.enumerated()), id: \.offset) { _, slot in
                            let musclesOk = slot.targetMuscleNames.allSatisfy { MuscleGroup(rawValue: $0) != nil }
                            let exOk: Bool = {
                                guard let suggested = slot.suggestedExerciseName else { return true }
                                return dataVM.globalExercises.contains { $0.name.caseInsensitiveCompare(suggested) == .orderedSame }
                            }()
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.label)
                                        .font(.body)
                                    Text(slot.targetMuscleNames.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(slot.sets)×\(slot.reps)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    if let s = slot.suggestedExerciseName {
                                        Text("Suggested: \(s)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if musclesOk && exOk {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    } else {
                        Label("Concrete workout", systemImage: "list.bullet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(day.exercises.enumerated()), id: \.offset) { _, ex in
                            let matched = dataVM.globalExercises.contains { $0.name.caseInsensitiveCompare(ex.name) == .orderedSame }
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.body)
                                    Text("\(ex.sets)×\(ex.reps)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if matched {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                } header: {
                    Text(day.name)
                }
            }

            Section {
                Toggle("Set as my training program", isOn: $updateTrainingProgram)
                Button {
                    Task { await apply(p) }
                } label: {
                    if isApplying {
                        HStack {
                            ProgressView()
                            Text("Applying…")
                        }
                    } else {
                        Text("Apply")
                    }
                }
                .disabled(isApplying)
                Button("Regenerate") {
                    proposal = nil
                    errorBanner = nil
                }
            }
        }
    }

    private var notConfiguredBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("AI not configured", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text("Add OPENAI_API_KEY or FITLOG_AI_BASE_URL in your Xcode scheme or Info.plist. See OPENAI_SETUP.md in the project.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var weekdayMultiSelect: some View {
        let days: [(Int, String)] = [
            (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
            (5, "Thu"), (6, "Fri"), (7, "Sat")
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
            ForEach(days, id: \.0) { wd, label in
                let on = selectedWeekdays.contains(wd)
                Button {
                    if on { selectedWeekdays.remove(wd) } else { selectedWeekdays.insert(wd) }
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "\(weekday)" }
        return symbols[weekday - 1]
    }

    private func composedContextForAPI() -> String {
        var lines: [String] = []
        lines.append("Primary goal: \(primaryGoal.rawValue)")
        lines.append("Equipment: \(equipment.rawValue)")
        lines.append("Preferred split style: \(splitPreference.rawValue)")

        let lim = String(limitationsNotes.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !lim.isEmpty {
            lines.append("Injuries / movements to limit: \(lim)")
        }
        let extra = String(additionalNotes.prefix(SplitBuilderLimits.maxOptionalFieldChars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty {
            lines.append("Additional notes: \(extra)")
        }

        return String(lines.joined(separator: "\n").prefix(SplitBuilderLimits.maxComposedContextChars))
    }

    @MainActor
    private func generate() async {
        errorBanner = nil
        isGenerating = true
        defer { isGenerating = false }

        aiService.wakeProxyHostIfNeeded()

        let allowed = dataVM.globalExercises.map(\.name).sorted()
        let existingTemplates = dataVM.userWorkouts.map(\.name) + dataVM.userWorkoutTemplates.map(\.name)
        let prefs = Array(selectedWeekdays).sorted()

        do {
            let result = try await aiService.generateWorkoutSplitProposal(
                interests: composedContextForAPI(),
                sessionsPerWeek: sessionsPerWeek,
                preferredWeekdays: prefs,
                experienceLevel: experience.rawValue,
                allowedExerciseNames: allowed,
                existingWorkoutTemplateNames: existingTemplates,
                definitionPreference: definitionPreference
            )
            proposal = result
        } catch {
            errorBanner = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private struct ProposalResolution {
        var unresolvedExerciseNames: Set<String> = []
    }

    private func resolveProposal(_ p: WorkoutSplitProposal) -> ProposalResolution {
        var unresolved: Set<String> = []
        for day in p.workouts {
            for ex in day.exercises {
                if !dataVM.globalExercises.contains(where: { $0.name.caseInsensitiveCompare(ex.name) == .orderedSame }) {
                    unresolved.insert(ex.name)
                }
            }
            if day.isSlotTemplateDay {
                for slot in day.slots {
                    for m in slot.targetMuscleNames where MuscleGroup(rawValue: m) == nil {
                        unresolved.insert(m)
                    }
                    if let s = slot.suggestedExerciseName,
                       !dataVM.globalExercises.contains(where: { $0.name.caseInsensitiveCompare(s) == .orderedSame }) {
                        unresolved.insert(s)
                    }
                }
            }
        }
        return ProposalResolution(unresolvedExerciseNames: unresolved)
    }

    @MainActor
    private func apply(_ p: WorkoutSplitProposal) async {
        isApplying = true
        defer { isApplying = false }

        dataVM.applyWorkoutSplitProposal(
            p,
            updateTrainingProgram: updateTrainingProgram,
            anchorDate: Date()
        )

        dismiss()
    }
}
