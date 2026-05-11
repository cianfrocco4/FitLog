//
//  ActiveProgramDetailView.swift
//  FitLog
//
//  Hub for viewing and adjusting the active dynamic program after it is applied.
//

import SwiftUI

struct ActiveProgramDetailView: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var nameDraft: String = ""
    @State private var sessionsPerWeek: Int = 3
    @State private var selectedWeekdays: Set<Int> = []
    @State private var anchorDate: Date = Date()
    @State private var busyPolicy: BusyDayPolicy = .skip
    @State private var showRemoveConfirm = false
    @State private var builderHydration: DynamicProgramState?
    @State private var showHydratedBuilder = false

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            Group {
                if let state = dataVM.dynamicProgramState {
                    programContent(state: state)
                } else {
                    ContentUnavailableView(
                        "No active program",
                        systemImage: "rectangle.stack",
                        description: Text("Create a program from Home or Coach, then apply it to your plan.")
                    )
                }
            }
            .navigationTitle("Your program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Closes this screen")
                }
            }
            .onAppear {
                syncLocalFieldsFromState()
            }
            .onChange(of: dataVM.dynamicProgramState?.program.name) { _, _ in
                syncLocalFieldsFromState()
            }
            .confirmationDialog(
                "Remove this program from your plan?",
                isPresented: $showRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove from plan", role: .destructive) {
                    dataVM.setDynamicProgramState(nil)
                    dismiss()
                }
                .accessibilityHint("Clears the dynamic program. Library workouts stay in your list.")

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The Plan tab will use your saved training rotation again. Workout templates remain in your library.")
            }
            .sheet(isPresented: $showHydratedBuilder, onDismiss: { builderHydration = nil }) {
                if let snapshot = builderHydration {
                    SplitBuilderView(hydrateFromState: snapshot)
                        .environment(dataVM)
                        .environment(currentVM)
                        .environmentObject(aiService)
                }
            }
        }
    }

    @ViewBuilder
    private func programContent(state: DynamicProgramState) -> some View {
        let program = state.program
        let pe = PeriodizationEngine(calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let placement = pe.blockPlacement(on: today, state: state)
        let sessionProgress = dataVM.dynamicProgramBlockSessionProgress(calendar: calendar)

        Form {
            Section {
                TextField("Program name", text: $nameDraft)
                    .font(.headline)
                    .textInputAutocapitalization(.words)
                    .onSubmit { commitNameIfChanged(programName: program.name) }

                HStack(spacing: 8) {
                    Label(
                        program.generatedWithAI ? "Built with AI" : "Built from presets",
                        systemImage: program.generatedWithAI ? "sparkles" : "books.vertical"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .accessibilityElement(children: .combine)

                LabeledContent("Created") {
                    Text(program.createdAt, format: .dateTime.month().day().year())
                }
                LabeledContent("Planned length") {
                    Text("\(program.plannedTotalWeeks) wk · \(program.blocks.count) blocks")
                }
            } header: {
                Text("Overview")
            }

            Section {
                if let placement {
                    HStack(alignment: .center, spacing: 14) {
                        if let pr = sessionProgress, pr.planned > 0 {
                            activeProgramProgressRing(completed: pr.completed, planned: pr.planned)
                                .accessibilityLabel("Sessions logged in this block through today, \(pr.completed) of \(pr.planned)")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            if program.blocks.count > 1 {
                                Text("Block \(placement.index + 1) of \(program.blocks.count): \(placement.block.name)")
                                    .font(.subheadline.weight(.semibold))
                                Text("Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(placement.block.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("Week \(placement.weekInBlock + 1) of \(placement.block.durationWeeks)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Program starts \(state.anchorDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !state.completedBlockIds.isEmpty {
                    Text("Completed phases: \(state.completedBlockIds.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Progress")
            }

            Section {
                DynamicProgramTimelineView(
                    program: program,
                    anchorDate: state.anchorDate,
                    builderViewModel: nil
                )
                .frame(minHeight: 200)
            } header: {
                Text("Timeline")
            }

            Section {
                Stepper("Strength days per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...7)
                    .onChange(of: sessionsPerWeek) { _, n in
                        dataVM.updateDynamicProgramSchedule(
                            sessionsPerWeek: n,
                            preferredWeekdays: Array(selectedWeekdays).sorted()
                        )
                    }

                Text("Optional: tap preferred training days. Leave none for Mon–Fri pool.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                activeProgramWeekdayGrid

                Picker("Busy day policy", selection: $busyPolicy) {
                    ForEach(BusyDayPolicy.allCases, id: \.self) { pol in
                        Text(policyMenuTitle(pol)).tag(pol)
                    }
                }
                .onChange(of: busyPolicy) { _, pol in
                    dataVM.updateDynamicProgramBusyDayPolicy(pol)
                }

                DatePicker("Program start", selection: $anchorDate, displayedComponents: .date)
                    .onChange(of: anchorDate) { _, d in
                        dataVM.updateDynamicProgramAnchorDate(d, calendar: calendar)
                    }
            } header: {
                Text("Schedule")
            } footer: {
                Text(busyPolicyFootnote(busyPolicy))
                    .font(.caption)
            }

            Section {
                ForEach(Array(program.blocks.enumerated()), id: \.element.id) { _, block in
                    DisclosureGroup {
                        ForEach(block.weeklyTemplates) { template in
                            if let wid = state.materializedTemplateWorkoutIds[template.id] {
                                ActiveProgramTemplateWorkoutLink(
                                    template: template,
                                    libraryWorkoutId: wid
                                )
                                .environment(dataVM)
                                .environment(currentVM)
                                .environmentObject(aiService)
                            } else {
                                Label(template.dayName, systemImage: "doc.text")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(block.durationWeeks) wk · \(block.focus.displayTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Blocks & templates")
            } footer: {
                Text("Open a template to edit exercises in your library. Use Program builder for phase-wide template edits.")
                    .font(.caption)
            }

            Section {
                Button {
                    commitNameIfChanged(programName: program.name)
                    if let snap = dataVM.dynamicProgramState {
                        builderHydration = snap
                        showHydratedBuilder = true
                    }
                } label: {
                    Label("Edit in Program builder", systemImage: "calendar.badge.clock")
                }
                .accessibilityHint("Opens the program builder on the preview step with your current program loaded")

                Button("Remove from plan", role: .destructive) {
                    showRemoveConfirm = true
                }
                .accessibilityHint("Stops using this dynamic program on your calendar")
            }
        }
    }

    private func syncLocalFieldsFromState() {
        guard let s = dataVM.dynamicProgramState else { return }
        nameDraft = s.program.name
        sessionsPerWeek = s.program.defaultSessionsPerWeek
        selectedWeekdays = Set(s.program.preferredWeekdays)
        busyPolicy = s.program.busyDayPolicy
        anchorDate = s.anchorDate
    }

    private func commitNameIfChanged(programName: String) {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != programName else { return }
        dataVM.updateDynamicProgramName(trimmed)
    }

    private var activeProgramWeekdayGrid: some View {
        let days: [(Int, String)] = [
            (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
            (5, "Thu"), (6, "Fri"), (7, "Sat")
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
            ForEach(days, id: \.0) { wd, label in
                let on = selectedWeekdays.contains(wd)
                Button {
                    if on { selectedWeekdays.remove(wd) } else { selectedWeekdays.insert(wd) }
                    dataVM.updateDynamicProgramSchedule(
                        sessionsPerWeek: sessionsPerWeek,
                        preferredWeekdays: Array(selectedWeekdays).sorted()
                    )
                } label: {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(on ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) weekday")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private func policyMenuTitle(_ pol: BusyDayPolicy) -> String {
        switch pol {
        case .compress: return "Compress week"
        case .shift: return "Shift block"
        case .flexDay: return "Flex day"
        case .skip: return "Skip (no auto change)"
        }
    }

    private func busyPolicyFootnote(_ pol: BusyDayPolicy) -> String {
        switch pol {
        case .compress:
            return "Busy-day policy: compress remaining sessions in the week."
        case .shift:
            return "Busy-day policy: extend the active block when you mark busy days."
        case .flexDay:
            return "Busy-day policy: lighter flex sessions on marked days."
        case .skip:
            return "Busy-day policy: skip — rotation stays on the default cadence."
        }
    }

    private func activeProgramProgressRing(completed: Int, planned: Int) -> some View {
        let total = max(1, planned)
        let frac = min(1, max(0, Double(completed) / Double(total)))
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.22), lineWidth: 6)
            Circle()
                .trim(from: 0, to: frac)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(completed)/\(planned)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(4)
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - Template row → library workout editor

private struct ActiveProgramTemplateWorkoutLink: View {
    @Environment(DataManager.self) private var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) private var currentVM
    @EnvironmentObject private var aiService: AIService

    let template: BlockWeeklyTemplate
    let libraryWorkoutId: UUID

    var body: some View {
        @Bindable var dm = dataVM
        if let binding = $dm.userWorkouts[libraryWorkoutId] {
            NavigationLink {
                WorkoutPlanView(workout: binding, currentVM: currentVM)
                    .environment(dataVM)
                    .environmentObject(aiService)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.dayName)
                        .font(.subheadline.weight(.semibold))
                    Text(binding.wrappedValue.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityHint("Opens this template’s library workout for editing")
        } else {
            Label(template.dayName, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}
