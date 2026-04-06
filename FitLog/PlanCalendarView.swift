//
//  PlanCalendarView.swift
//  FitLog
//

import SwiftUI

// MARK: - Calendar grid

struct PlanCalendarView: View {
    @EnvironmentObject var dayMonitor: CalendarDayMonitor
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel

    @State private var visibleMonth: Date = Date()
    @State private var daySheetDate: Date?
    @State private var weekEditAnchor: Date?
    @State private var showSplitEditor = false
    @State private var showSetup = false
    @State private var resolvedDayCache: [String: ResolvedScheduleDay] = [:]
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?

    private var calendar: Calendar { .current }

    /// Drives `.task` refresh for day rollover and session count; full program edits use `onChange(of: trainingProgram)` because count-based keys miss reorder / swap-with-same-length / override body changes.
    private var calendarRefreshKey: String {
        let p = dataVM.trainingProgram
        let cycleSig = p.cycleEntries.map(\.cacheKey).joined(separator: ",")
        let weekdaysSig = p.preferredWeekdays.map(String.init).joined(separator: ",")
        return "\(dayMonitor.currentDayKey)-\(cycleSig)-\(p.sessionsPerWeek)-\(weekdaysSig)-\(p.anchorDayKey)-\(p.dayOverrides.count)-\(p.weekOverrides.count)-\(p.frozenCalendarDays.count)-\(dataVM.completedSessions.count)"
    }

    private func rebuildResolvedDayCache() {
        let days = daysInMonthGrid(for: visibleMonth)
        var cache: [String: ResolvedScheduleDay] = [:]
        for day in days {
            guard let d = day else { continue }
            let key = TrainingProgramState.dayKey(for: d, calendar: calendar)
            cache[key] = dataVM.resolvedScheduleDay(for: d, calendar: calendar)
        }
        resolvedDayCache = cache
    }

    private func cachedResolve(date: Date) -> ResolvedScheduleDay {
        let key = TrainingProgramState.dayKey(for: date, calendar: calendar)
        return resolvedDayCache[key] ?? dataVM.resolvedScheduleDay(for: date, calendar: calendar)
    }

    private var orderedShortWeekdays: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                calendarGrid
                legend
            }
            .task(id: calendarRefreshKey) {
                rebuildResolvedDayCache()
            }
            .onChange(of: dataVM.trainingProgram) { _, _ in
                rebuildResolvedDayCache()
            }
            .onChange(of: visibleMonth) { _, _ in
                rebuildResolvedDayCache()
            }
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Plan")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSplitEditor = true
                    } label: {
                        Label("Split", systemImage: "arrow.triangle.swap")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSetup = true
                    } label: {
                        Label("Schedule", systemImage: "calendar.badge.clock")
                    }
                }
            }
            .sheet(item: Binding(
                get: { daySheetDate.map { DaySheetItem(date: $0) } },
                set: { daySheetDate = $0?.date }
            )) { item in
                DayPlanSheet(date: item.date)
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
            }
            .sheet(item: Binding(
                get: { weekEditAnchor.map { WeekSheetItem(anchor: $0) } },
                set: { weekEditAnchor = $0?.anchor }
            )) { item in
                WeekOverrideSheet(weekContaining: item.anchor)
                    .environmentObject(dataVM)
            }
            .sheet(isPresented: $showSplitEditor) {
                SplitEditorSheet()
                    .environmentObject(dataVM)
            }
            .sheet(isPresented: $showSetup) {
                ProgramSetupSheet()
                    .environmentObject(dataVM)
            }
            .workoutReplaceConflictConfirmation(currentVM: currentVM, pending: $pendingWorkoutReplace)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                visibleMonth = calendar.date(byAdding: .month, value: -1, to: visibleMonth) ?? visibleMonth
            } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(visibleMonth, format: .dateTime.month(.wide).year())
                .font(.title3.weight(.semibold))
            Spacer()
            Button {
                visibleMonth = calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            ForEach(orderedShortWeekdays, id: \.self) { sym in
                Text(sym)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var calendarGrid: some View {
        let days = daysInMonthGrid(for: visibleMonth)
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, cell in
                    if let date = cell {
                        dayCell(date: date)
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(8)
        }
    }

    private func dayCell(date: Date) -> some View {
        let resolved = cachedResolve(date: date)
        let isToday = calendar.isDateInToday(date)
        let subtitle = dayPlanSubtitle(date: date, resolved: resolved)
        let isPastDay = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())

        return VStack(alignment: .leading, spacing: 4) {
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 30, height: 30)
                }
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Color.white : Color.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)

            if isToday {
                Text("Today")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(subtitle)
                .font(.caption2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isToday ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: isToday ? 1.5 : 0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDayLabel(date: date, isToday: isToday, subtitle: subtitle))
        .contentShape(Rectangle())
        .onTapGesture {
            daySheetDate = date
        }
        .contextMenu {
            Button("Edit this week") {
                weekEditAnchor = date
            }
            if !isPastDay, case .workout(let ref) = resolved {
                let id = ref.libraryWorkoutId
                if let w = dataVM.workout(id: id) {
                    Button("Start workout") {
                        let session = w.hasFlexibleSlots ? dataVM.sessionInstance(from: w) : w
                        currentVM.startWorkoutResolvingConflict(session, sessionPlanOrigin: .workout(id)) {
                            pendingWorkoutReplace = $0
                        }
                    }
                }
            }
        }
    }

    private func dayPlanSubtitle(date: Date, resolved: ResolvedScheduleDay) -> String {
        if let s = dataVM.primaryCompletedSession(on: date, calendar: calendar) {
            return s.workout.name
        }
        switch resolved {
        case .rest:
            return "Rest"
        case .unscheduled:
            return "—"
        case .workout(let ref):
            return dataVM.planLabel(for: ref)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tip: tap a day to swap or mark rest. Long-press (or context menu) to edit the whole week.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func accessibilityDayLabel(date: Date, isToday: Bool, subtitle: String) -> String {
        let when = date.formatted(date: .abbreviated, time: .omitted)
        let prefix = isToday ? "Today, " : ""
        return "\(prefix)\(when). \(subtitle)."
    }

    private func daysInMonthGrid(for month: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let monthStart = monthInterval.start
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let lead = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: lead)
        for day in monthRange {
            var comp = calendar.dateComponents([.year, .month], from: monthStart)
            comp.day = day
            if let d = calendar.date(from: comp) {
                cells.append(d)
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }
}

// MARK: - Sheet item wrappers (Identifiable)

private struct DaySheetItem: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

private struct WeekSheetItem: Identifiable {
    let anchor: Date
    var id: String { TrainingProgramState.isoWeekKey(for: anchor) }
}

// MARK: - Day plan sheet

struct DayPlanSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var swapPlanRef: WorkoutPlanRef?
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?

    private var calendar: Calendar { .current }
    private var dayKey: String { TrainingProgramState.dayKey(for: date, calendar: calendar) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(date, style: .date)
                        .font(.headline)
                }

                Section("Assignment") {
                    let resolved = dataVM.resolvedScheduleDay(for: date, calendar: calendar)
                    switch resolved {
                    case .rest:
                        Label("Rest day", systemImage: "moon.zzz")
                    case .unscheduled:
                        Label("Off / unscheduled", systemImage: "circle.dashed")
                    case .workout(let ref):
                        Label(dataVM.planLabel(for: ref), systemImage: "dumbbell")
                    }
                }

                if let done = dataVM.primaryCompletedSession(on: date, calendar: calendar) {
                    Section("Completed") {
                        Label(done.workout.name, systemImage: "checkmark.circle.fill")
                    }
                }

                if calendar.startOfDay(for: date) >= calendar.startOfDay(for: Date()) {
                    Section("Actions") {
                        if case .workout(let ref) = dataVM.resolvedScheduleDay(for: date, calendar: calendar),
                           let w = dataVM.workout(id: ref.libraryWorkoutId) {
                            Button("Start workout") {
                                let session = w.hasFlexibleSlots ? dataVM.sessionInstance(from: w) : w
                                switch currentVM.resolveStartingWorkout(session, sessionPlanOrigin: .workout(w.id)) {
                                case .performStart:
                                    currentVM.startWorkout(session, sessionPlanOrigin: .workout(w.id))
                                    dismiss()
                                case .noOpAlreadyActive:
                                    dismiss()
                                case .needsReplaceConfirmation(let p):
                                    pendingWorkoutReplace = p
                                }
                            }
                        }

                        Picker("Swap to workout", selection: $swapPlanRef) {
                            Text("Choose…").tag(nil as WorkoutPlanRef?)
                            Section("Library") {
                                ForEach(dataVM.userWorkouts) { w in
                                    Text(w.name).tag(Optional(WorkoutPlanRef.workout(w.id)))
                                }
                            }
                        }
                        Button("Apply swap") {
                            guard let ref = swapPlanRef else { return }
                            dataVM.setTrainingDayOverride(dayKey: dayKey, intent: .workout, planRef: ref)
                        }
                        .disabled(swapPlanRef == nil)

                        Button("Mark rest day") {
                            dataVM.setTrainingDayOverride(dayKey: dayKey, intent: .rest)
                        }

                        Button("Use default plan") {
                            dataVM.clearTrainingDayOverride(dayKey: dayKey)
                        }
                    }
                }

                Section {
                    if let wid = planWorkoutIdForLink, let w = dataVM.workout(id: wid) {
                        if w.hasFlexibleSlots {
                            NavigationLink("Edit open slots") {
                                SlotTemplatePlanView(workoutId: wid)
                                    .environmentObject(dataVM)
                                    .environmentObject(currentVM)
                            }
                        } else {
                            NavigationLink("Open workout") {
                                if let binding = $dataVM.userWorkouts[wid] {
                                    WorkoutPlanView(workout: binding)
                                } else {
                                    Text("This workout was removed from your library.")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .workoutReplaceConflictConfirmation(
                currentVM: currentVM,
                pending: $pendingWorkoutReplace,
                onAfterReplace: { dismiss() }
            )
            .onAppear {
                if let o = dataVM.trainingProgram.dayOverrides[dayKey], o.intent == .workout {
                    swapPlanRef = o.planRef
                } else {
                    swapPlanRef = nil
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var planWorkoutIdForLink: UUID? {
        switch dataVM.resolvedScheduleDay(for: date, calendar: calendar) {
        case .workout(let ref):
            return ref.libraryWorkoutId
        default:
            return nil
        }
    }
}

// MARK: - Week override sheet

struct WeekOverrideSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) private var dismiss

    let weekContaining: Date

    private var calendar: Calendar { .current }
    private var weekKey: String { TrainingProgramState.isoWeekKey(for: weekContaining, calendar: calendar) }

    /// Weekdays in order for this calendar (e.g. Sun…Sat).
    private var weekDaysOrdered: [(weekday: Int, date: Date)] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: weekContaining) else { return [] }
        var d = interval.start
        var out: [(Int, Date)] = []
        while d < interval.end {
            let wd = calendar.component(.weekday, from: d)
            out.append((wd, calendar.startOfDay(for: d)))
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? interval.end
        }
        return out
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("ISO week \(weekKey)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("This week only (overrides base plan)") {
                    ForEach(weekDaysOrdered, id: \.date) { pair in
                        WeekdayRow(
                            title: "\(weekdayName(pair.weekday)) · \(shortDate(pair.date))",
                            weekKey: weekKey,
                            weekday: pair.weekday,
                            defaultResolved: dataVM.resolvedScheduleDay(for: pair.date, calendar: calendar)
                        )
                    }
                }

                Section {
                    Button("Clear all overrides for this week", role: .destructive) {
                        dataVM.clearWeekOverride(weekKey: weekKey)
                    }
                }
            }
            .navigationTitle("Edit week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func weekdayName(_ wd: Int) -> String {
        let idx = (wd + 6) % 7
        let symbols = calendar.weekdaySymbols
        guard idx < symbols.count else { return "\(wd)" }
        return symbols[idx]
    }

    private func shortDate(_ d: Date) -> String {
        d.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct WeekdayRow: View {
    @EnvironmentObject var dataVM: DataManager

    let title: String
    let weekKey: String
    let weekday: Int
    let defaultResolved: ResolvedScheduleDay

    @State private var mode: Int = 0
    @State private var pickedPlanRef: WorkoutPlanRef?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text("Default (no week override): \(defaultLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Override", selection: $mode) {
                Text("Inherit").tag(0)
                Text("Rest").tag(1)
                Text("Workout").tag(2)
            }
            .pickerStyle(.segmented)
            .onAppear {
                syncFromStore()
            }
            .onChange(of: mode) { _, _ in
                persist()
            }

            if mode == 2 {
                Picker("Workout", selection: $pickedPlanRef) {
                    Text("Choose…").tag(nil as WorkoutPlanRef?)
                    Section("Library") {
                        ForEach(dataVM.userWorkouts) { w in
                            Text(w.name).tag(Optional(WorkoutPlanRef.workout(w.id)))
                        }
                    }
                }
                .onChange(of: pickedPlanRef) { _, _ in
                    persist()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var defaultLabel: String {
        switch defaultResolved {
        case .rest: return "Rest"
        case .unscheduled: return "Off"
        case .workout(let ref):
            return dataVM.planLabel(for: ref)
        }
    }

    private func syncFromStore() {
        if let o = dataVM.trainingProgram.weekOverrides[weekKey]?.weekdayOverrides[String(weekday)] {
            switch o.intent {
            case .inherit:
                mode = 0
            case .rest:
                mode = 1
            case .workout:
                mode = 2
                pickedPlanRef = o.planRef
            }
        } else {
            mode = 0
            pickedPlanRef = nil
        }
    }

    private func persist() {
        switch mode {
        case 0:
            dataVM.setWeekDayOverride(weekKey: weekKey, weekday: weekday, intent: .inherit)
        case 1:
            dataVM.setWeekDayOverride(weekKey: weekKey, weekday: weekday, intent: .rest)
        case 2:
            guard let ref = pickedPlanRef else { return }
            dataVM.setWeekDayOverride(weekKey: weekKey, weekday: weekday, intent: .workout, planRef: ref)
        default:
            break
        }
    }
}

// MARK: - Split editor

struct SplitEditorSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Drag to reorder the cycle. This is your overall split; calendar day edits do not change this order.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Cycle") {
                    ForEach(Array(dataVM.trainingProgram.cycleEntries.enumerated()), id: \.offset) { _, entry in
                        HStack {
                            Text(dataVM.planLabel(for: entry))
                            Spacer()
                            switch entry {
                            case .workout(let id):
                                if dataVM.workout(id: id) == nil {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        var entries = dataVM.trainingProgram.cycleEntries
                        entries.remove(atOffsets: indexSet)
                        dataVM.setTrainingCycleEntries(entries)
                    }
                    .onMove { source, dest in
                        var entries = dataVM.trainingProgram.cycleEntries
                        entries.move(fromOffsets: source, toOffset: dest)
                        dataVM.setTrainingCycleEntries(entries)
                    }
                }

                Section("Add from library") {
                    let inCycle: (UUID) -> Bool = { wid in
                        dataVM.trainingProgram.cycleEntries.contains { $0 == .workout(wid) }
                    }
                    ForEach(dataVM.userWorkouts.filter { !inCycle($0.id) }) { w in
                        Button {
                            var entries = dataVM.trainingProgram.cycleEntries
                            entries.append(.workout(w.id))
                            dataVM.setTrainingCycleEntries(entries)
                        } label: {
                            Label(w.name, systemImage: "plus.circle")
                        }
                    }
                }

            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Workout split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Program setup / suggest

struct ProgramSetupSheet: View {
    @EnvironmentObject var dataVM: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var sessionsPerWeek: Int = 3
    @State private var selectedWeekdays: Set<Int> = []
    @State private var anchorDate: Date = Date()
    @State private var cycleEntriesDraft: [WorkoutPlanRef] = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Workouts per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...7)
                    Text("Preferred training days (optional). Leave none selected to use Monday–Friday as the pool.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    weekdayMultiSelect
                    DatePicker("Rotation anchor", selection: $anchorDate, displayedComponents: .date)
                    Text("The anchor sets where the cycle starts counting. Changing it shifts default assignments.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Cycle for suggestions") {
                    if cycleEntriesDraft.isEmpty {
                        Text("Add workouts from your library below — order is the split order.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(cycleEntriesDraft.enumerated()), id: \.offset) { _, entry in
                            Text(dataVM.planLabel(for: entry))
                        }
                        .onMove { s, d in
                            cycleEntriesDraft.move(fromOffsets: s, toOffset: d)
                        }
                    }
                    let inDraft: (UUID) -> Bool = { wid in
                        cycleEntriesDraft.contains { $0 == .workout(wid) }
                    }
                    ForEach(dataVM.userWorkouts.filter { !inDraft($0.id) }) { w in
                        Button {
                            cycleEntriesDraft.append(.workout(w.id))
                        } label: {
                            Label("Add \(w.name)", systemImage: "plus.circle")
                        }
                    }
                }

                Section {
                    Button("Apply schedule") {
                        let prefs = Array(selectedWeekdays).sorted()
                        dataVM.applyTrainingProgramSuggestion(
                            cycleEntries: cycleEntriesDraft,
                            sessionsPerWeek: sessionsPerWeek,
                            preferredWeekdays: prefs,
                            anchorDate: anchorDate
                        )
                        dismiss()
                    }
                    .disabled(cycleEntriesDraft.isEmpty)
                }
            }
            .navigationTitle("Schedule setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .environment(\.editMode, .constant(.active))
            .onAppear {
                sessionsPerWeek = dataVM.trainingProgram.sessionsPerWeek
                selectedWeekdays = Set(dataVM.trainingProgram.preferredWeekdays)
                if let d = TrainingProgramState.date(fromDayKey: dataVM.trainingProgram.anchorDayKey) {
                    anchorDate = d
                }
                cycleEntriesDraft = dataVM.trainingProgram.cycleEntries
            }
        }
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
}
