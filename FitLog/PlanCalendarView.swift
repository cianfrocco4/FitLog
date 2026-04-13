//
//  PlanCalendarView.swift
//  FitLog
//

import SwiftUI
import UIKit

// MARK: - Haptics

private enum FitlogHaptics {
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Calendar grid

struct PlanCalendarView: View {
    @EnvironmentObject var dayMonitor: CalendarDayMonitor
    @EnvironmentObject var dataVM: DataManager
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var aiService: AIService
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.fitlogCoachDeepLink) private var coachDeepLink

    @State private var visibleMonth: Date = Date()
    @State private var weekStripWeekOffset: Int = 0
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
        let skipSig = p.skippedCycleTrainingDayKeys.joined(separator: ",")
        return "\(dayMonitor.currentDayKey)-\(cycleSig)-\(p.sessionsPerWeek)-\(weekdaysSig)-\(p.anchorDayKey)-\(p.cyclePhaseOffset)-\(skipSig)-\(p.dayOverrides.count)-\(p.weekOverrides.count)-\(p.frozenCalendarDays.count)-\(dataVM.completedSessions.count)"
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
            ScrollView {
                VStack(spacing: 0) {
                    monthHeader
                    weekStrip
                    weekdayHeader
                    calendarGridContent
                    legend
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 45)
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > 52, abs(dx) > abs(dy) * 1.2 else { return }
                            FitlogHaptics.lightImpact()
                            if dx < 0 {
                                advanceVisibleMonth(by: 1)
                            } else {
                                advanceVisibleMonth(by: -1)
                            }
                        }
                )
            }
            .refreshable {
                await MainActor.run {
                    dataVM.reconcileSkippedCycleTrainingDays()
                    rebuildResolvedDayCache()
                    dataVM.publishWidgetSnapshot()
                }
            }
            .task(id: calendarRefreshKey) {
                rebuildResolvedDayCache()
            }
            .onChange(of: dataVM.trainingProgram) { _, _ in
                rebuildResolvedDayCache()
            }
            .onChange(of: visibleMonth) { _, _ in
                weekStripWeekOffset = 0
                rebuildResolvedDayCache()
            }
            .fitlogWorkoutBarContentInset()
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSplitEditor = true
                    } label: {
                        Label("Split", systemImage: "arrow.triangle.swap")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openCoachSplitBuilderWithPlanContext()
                    } label: {
                        Label("AI split", systemImage: "sparkles")
                    }
                    .accessibilityHint("Opens Coach with your current plan in the AI split builder")
                    Button {
                        jumpToTodayMonth()
                    } label: {
                        Label("Today", systemImage: "sun.max.fill")
                    }
                    .accessibilityHint("Shows the month containing today")
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
                    .environmentObject(aiService)
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
                    .environmentObject(currentVM)
                    .environmentObject(aiService)
            }
            .sheet(isPresented: $showSetup) {
                ProgramSetupSheet()
                    .environmentObject(dataVM)
            }
            .workoutReplaceConflictConfirmation(currentVM: currentVM, pending: $pendingWorkoutReplace)
        }
    }

    private func jumpToTodayMonth() {
        FitlogHaptics.mediumImpact()
        let today = Date()
        visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        weekStripWeekOffset = 0
    }

    private func advanceVisibleMonth(by months: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: months, to: visibleMonth) ?? visibleMonth
    }

    private func openCoachSplitBuilderWithPlanContext() {
        FitlogHaptics.lightImpact()
        coachDeepLink.wrappedValue = .openAISplitBuilder(prefill: dataVM.planCycleContextLineForCoach())
        rootTabSelection?.wrappedValue = .coach
    }

    // MARK: - Week strip (focused week)

    private var weekStripAnchorDate: Date {
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
        let today = Date()
        if calendar.isDate(today, equalTo: visibleMonth, toGranularity: .month) {
            return today
        }
        return firstOfMonth
    }

    private var weekStripReferenceDate: Date {
        calendar.date(byAdding: .weekOfYear, value: weekStripWeekOffset, to: weekStripAnchorDate) ?? weekStripAnchorDate
    }

    private var weekStripDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: weekStripReferenceDate) else { return [] }
        var d = interval.start
        var out: [Date] = []
        while d < interval.end {
            out.append(calendar.startOfDay(for: d))
            guard let n = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = n
        }
        return out
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("This week")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Button {
                        weekStripWeekOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous week")

                    Button {
                        FitlogHaptics.mediumImpact()
                        weekStripWeekOffset = 0
                        let today = Date()
                        visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
                    } label: {
                        Text("This week")
                            .font(.caption.weight(.semibold))
                    }

                    Button {
                        weekStripWeekOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next week")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weekStripDays, id: \.self) { day in
                        weekStripDayCell(day: day)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 6)
    }

    private func weekStripDayCell(day: Date) -> some View {
        let resolved = cachedResolve(date: day)
        let isToday = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let status = dayStatus(date: day, resolved: resolved)
        let subtitle = dayPlanSubtitle(date: day, resolved: resolved)

        return Button {
            FitlogHaptics.lightImpact()
            if !inMonth {
                visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? visibleMonth
            }
            daySheetDate = day
        } label: {
            VStack(spacing: 4) {
                Text(shortWeekdaySymbol(for: day))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                statusDot(for: status)
            }
            .frame(minWidth: 40)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isToday ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isToday ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: isToday ? 1.5 : 0)
            )
            .opacity(inMonth ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(subtitle). \(accessibilityStatusLabel(status)).")
    }

    private func shortWeekdaySymbol(for date: Date) -> String {
        let idx = calendar.component(.weekday, from: date) - 1
        guard idx >= 0, idx < calendar.shortWeekdaySymbols.count else { return "" }
        return String(calendar.shortWeekdaySymbols[idx].prefix(1))
    }

    private enum PlanDayStatus {
        case logged
        case missedWorkout
        case rest
        case unscheduled
        case plannedWorkout
    }

    private func dayStatus(date: Date, resolved: ResolvedScheduleDay) -> PlanDayStatus {
        if dataVM.primaryCompletedSession(on: date, calendar: calendar) != nil {
            return .logged
        }
        let past = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
        switch resolved {
        case .rest:
            return .rest
        case .unscheduled:
            return .unscheduled
        case .workout:
            if past {
                return .missedWorkout
            }
            return .plannedWorkout
        }
    }

    @ViewBuilder
    private func statusDot(for status: PlanDayStatus) -> some View {
        switch status {
        case .logged:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(FitlogPalette.success)
        case .missedWorkout:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(FitlogPalette.caution)
        case .rest:
            Image(systemName: "moon.zzz.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .unscheduled:
            Image(systemName: "circle.dashed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .plannedWorkout:
            Image(systemName: "dumbbell.fill")
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
        }
    }

    private func accessibilityStatusLabel(_ status: PlanDayStatus) -> String {
        switch status {
        case .logged: return "Logged workout"
        case .missedWorkout: return "Missed planned workout"
        case .rest: return "Rest"
        case .unscheduled: return "Unscheduled"
        case .plannedWorkout: return "Workout planned"
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

    private var calendarGridContent: some View {
        let days = daysInMonthGrid(for: visibleMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
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

    private func dayCell(date: Date) -> some View {
        let resolved = cachedResolve(date: date)
        let isToday = calendar.isDateInToday(date)
        let isPastDay = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
        let subtitle = dayPlanSubtitle(date: date, resolved: resolved)
        let status = dayStatus(date: date, resolved: resolved)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
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
                .accessibilityHidden(true)
                Spacer(minLength: 0)
                statusDot(for: status)
            }

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
        .accessibilityLabel(accessibilityDayLabel(date: date, isToday: isToday, subtitle: subtitle, status: status))
        .contentShape(Rectangle())
        .onTapGesture {
            FitlogHaptics.lightImpact()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("Logged", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(FitlogPalette.success)
                Label("Missed", systemImage: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(FitlogPalette.caution)
                Label("Rest", systemImage: "moon.zzz.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label("Planned", systemImage: "dumbbell.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
            }
            Text("Tip: swipe left or right on the calendar to change months. Pull to refresh plan data. Tap a day to swap or mark rest. Long-press (or context menu) to edit the whole week. Missed planned workouts advance the rotation so upcoming days stay in sync.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func accessibilityDayLabel(date: Date, isToday: Bool, subtitle: String, status: PlanDayStatus) -> String {
        let when = date.formatted(date: .abbreviated, time: .omitted)
        let prefix = isToday ? "Today, " : ""
        return "\(prefix)\(when). \(subtitle). \(accessibilityStatusLabel(status))."
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
    @EnvironmentObject var aiService: AIService
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

                if calendar.startOfDay(for: date) >= calendar.startOfDay(for: Date()),
                   case .workout(let ref) = dataVM.resolvedScheduleDay(for: date, calendar: calendar) {
                    Section {
                        Text("Sets this calendar day as the rotation anchor so upcoming default assignments continue from this template. Per-day swaps already apply; use this after you reshuffle the week and want the split to line up again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Align rotation from this workout") {
                            dataVM.realignTrainingCycleAnchor(to: date, for: ref, calendar: calendar)
                            dismiss()
                        }
                    } header: {
                        Text("Rotation")
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
                    if let wid = planWorkoutIdForLink {
                        NavigationLink("Open workout") {
                            if let binding = $dataVM.userWorkouts[wid] {
                                WorkoutPlanView(workout: binding)
                                    .environmentObject(dataVM)
                                    .environmentObject(currentVM)
                                    .environmentObject(aiService)
                            } else {
                                Text("This workout was removed from your library.")
                                    .foregroundStyle(.secondary)
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
    @EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss
    @State private var showScheduleSetup = false
    @State private var showClearCycleConfirm = false
    @State private var clearedRotationUndo: [WorkoutPlanRef]?
    @State private var clearRotationUndoTask: Task<Void, Never>?

    private var program: TrainingProgramState { dataVM.trainingProgram }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This list is the rotation order for training days in your weekly pattern (set under Schedule). Reorder for Push/Pull/Legs or any split; duplicates are allowed if you repeat a day type.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showScheduleSetup = true
                        } label: {
                            Label("Weekly pattern & anchor…", systemImage: "calendar.badge.clock")
                        }
                    }
                }

                if !program.cycleEntries.isEmpty {
                    Section {
                        LabeledContent("Workouts per week", value: "\(program.sessionsPerWeek)")
                        if program.preferredWeekdays.isEmpty {
                            Text("Training day pool: Mon–Fri (default)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Preferred days: \(preferredWeekdaySummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Schedule summary")
                    }
                }

                Section {
                    ForEach(Array(program.cycleEntries.enumerated()), id: \.offset) { index, entry in
                        NavigationLink {
                            workoutEditorDestination(for: entry)
                        } label: {
                            cycleRowLabel(index: index, entry: entry)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                duplicateEntry(at: index)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(FitlogPalette.chartPrimary)
                        }
                    }
                    .onDelete { indexSet in
                        var entries = program.cycleEntries
                        entries.remove(atOffsets: indexSet)
                        dataVM.setTrainingCycleEntries(entries)
                    }
                    .onMove { source, dest in
                        var entries = program.cycleEntries
                        entries.move(fromOffsets: source, toOffset: dest)
                        dataVM.setTrainingCycleEntries(entries)
                    }
                } header: {
                    Text("Rotation (\(program.cycleEntries.count))")
                } footer: {
                    Text("Tip: open a workout to edit exercises. Duplicating adds another step in the rotation.")
                        .font(.caption)
                }

                Section("Add to rotation") {
                    let inCycle: (UUID) -> Bool = { wid in
                        program.cycleEntries.contains { $0 == .workout(wid) }
                    }
                    if dataVM.userWorkouts.allSatisfy({ inCycle($0.id) }) {
                        Text("Every library workout is already in the rotation. You can still duplicate steps above.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(dataVM.userWorkouts.filter { !inCycle($0.id) }) { w in
                        Button {
                            var entries = program.cycleEntries
                            entries.append(.workout(w.id))
                            dataVM.setTrainingCycleEntries(entries)
                        } label: {
                            Label(w.name, systemImage: "plus.circle.fill")
                        }
                    }
                }

                Section {
                    Button("Clear entire rotation", role: .destructive) {
                        showClearCycleConfirm = true
                    }
                    .disabled(program.cycleEntries.isEmpty)
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
            .sheet(isPresented: $showScheduleSetup) {
                ProgramSetupSheet()
                    .environmentObject(dataVM)
            }
            .confirmationDialog("Clear all workouts from the rotation?", isPresented: $showClearCycleConfirm, titleVisibility: .visible) {
                Button("Clear rotation", role: .destructive) {
                    let previous = program.cycleEntries
                    dataVM.setTrainingCycleEntries([])
                    clearedRotationUndo = previous
                    clearRotationUndoTask?.cancel()
                    clearRotationUndoTask = Task {
                        try? await Task.sleep(nanoseconds: 12_000_000_000)
                        await MainActor.run {
                            clearedRotationUndo = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay(alignment: .bottom) {
                if let entries = clearedRotationUndo {
                    HStack {
                        Text("Rotation cleared")
                            .font(.subheadline)
                        Spacer()
                        Button("Undo") {
                            clearRotationUndoTask?.cancel()
                            dataVM.setTrainingCycleEntries(entries)
                            clearedRotationUndo = nil
                        }
                        .fontWeight(.semibold)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onDisappear {
                clearRotationUndoTask?.cancel()
            }
        }
    }

    private var preferredWeekdaySummary: String {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols
        let first = cal.firstWeekday - 1
        let ordered = Array(symbols[first...]) + Array(symbols[..<first])
        let labels = program.preferredWeekdays.sorted().map { wd -> String in
            let idx = (wd + 6) % 7
            guard idx < ordered.count else { return "\(wd)" }
            return ordered[idx]
        }
        return labels.joined(separator: ", ")
    }

    @ViewBuilder
    private func workoutEditorDestination(for entry: WorkoutPlanRef) -> some View {
        switch entry {
        case .workout(let id):
            if let binding = $dataVM.userWorkouts[id] {
                WorkoutPlanView(workout: binding)
                    .environmentObject(dataVM)
                    .environmentObject(currentVM)
                    .environmentObject(aiService)
            } else {
                Text("This workout is missing from your library.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cycleRowLabel(index: Int, entry: WorkoutPlanRef) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(dataVM.planLabel(for: entry))
                Text("Repeating rotation step")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            switch entry {
            case .workout(let wid):
                if dataVM.workout(id: wid) == nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(FitlogPalette.caution)
                }
            }
        }
    }

    private func duplicateEntry(at index: Int) {
        var entries = program.cycleEntries
        guard index < entries.count else { return }
        let copy = entries[index]
        entries.insert(copy, at: index + 1)
        dataVM.setTrainingCycleEntries(entries)
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
