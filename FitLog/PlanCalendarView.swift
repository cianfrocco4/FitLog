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
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var aiService: AIService
    @Environment(\.fitlogRootTabSelection) private var rootTabSelection
    @Environment(\.fitlogCoachDeepLink) private var coachDeepLink

    @State private var visibleMonth: Date = Date()
    @State private var weekStripWeekOffset: Int = 0
    @State private var daySheetDate: Date?
    @State private var weekEditAnchor: Date?
    @State private var showProgramBuilder = false
    @State private var showActiveProgramDetail = false
    @State private var resolvedDayCache: [String: ResolvedScheduleDay] = [:]
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?
    @State private var blockTransitionToast: String?
    @State private var blockTransitionToastSerial = 0

    private var calendar: Calendar { .current }

    /// Drives `.task` refresh for day rollover and session count; full program edits use `onChange(of: trainingProgram)` because count-based keys miss reorder / swap-with-same-length / override body changes.
    private var calendarRefreshKey: String {
        let p = dataVM.trainingProgram
        let cycleSig = p.cycleEntries.map(\.cacheKey).joined(separator: ",")
        let weekdaysSig = p.preferredWeekdays.map(String.init).joined(separator: ",")
        let skipSig = p.skippedCycleTrainingDayKeys.joined(separator: ",")
        let dynSig: String = {
            guard let d = dataVM.dynamicProgramState else { return "dyn:none" }
            let shiftSig = d.blockShiftDays.map { "\($0.key.uuidString):\($0.value)" }.sorted().joined(separator: ",")
            return "dyn:\(d.program.id.uuidString)-\(Int(d.anchorDate.timeIntervalSince1970))-\(d.materializedTemplateWorkoutIds.count)-\(d.program.blocks.count)-\(d.busyDayKeys.count)-\(d.missedSessionDayKeys.count)-\(shiftSig)"
        }()
        return "\(dayMonitor.currentDayKey)-\(cycleSig)-\(p.sessionsPerWeek)-\(weekdaysSig)-\(p.anchorDayKey)-\(p.cyclePhaseOffset)-\(skipSig)-\(p.dayOverrides.count)-\(p.weekOverrides.count)-\(p.frozenCalendarDays.count)-\(dataVM.completedSessions.count)-\(dynSig)"
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
                    if let blockTransitionToast {
                        Text(blockTransitionToast)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15)))
                            .padding(.horizontal)
                            .accessibilityLabel(blockTransitionToast)
                    }
                    dynamicProgramStatusBanner
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
            .workoutBottomScrollClearance()
            .onReceive(NotificationCenter.default.publisher(for: .fitlogOpenProgramBuilder)) { _ in
                showProgramBuilder = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .fitlogDynamicProgramBlockChanged)) { note in
                let name = (note.userInfo?["newBlockName"] as? String) ?? "Next block"
                let idx = (note.userInfo?["newBlockIndex"] as? Int) ?? 0
                let total = (note.userInfo?["blockCount"] as? Int) ?? 0
                blockTransitionToastSerial += 1
                let serial = blockTransitionToastSerial
                blockTransitionToast = total > 0 ? "Now in block \(idx) of \(total): \(name)" : "New training phase: \(name)"
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if serial == blockTransitionToastSerial {
                        blockTransitionToast = nil
                    }
                }
            }
            .task(id: calendarRefreshKey) {
                rebuildResolvedDayCache()
            }
            .onChange(of: dataVM.trainingProgram) { _, _ in
                rebuildResolvedDayCache()
                dataVM.publishWidgetSnapshot()
            }
            .onChange(of: dataVM.dynamicProgramState) { _, _ in
                rebuildResolvedDayCache()
            }
            .onChange(of: visibleMonth) { _, _ in
                weekStripWeekOffset = 0
                rebuildResolvedDayCache()
            }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showProgramBuilder = true
                    } label: {
                        Label("Program", systemImage: "rectangle.grid.1x2")
                    }
                    .accessibilityHint("Weekly schedule and training day order")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        openCoachDynamicProgramBuilderWithPlanContext()
                    } label: {
                        Label("Build program", systemImage: "calendar.badge.clock")
                    }
                    .accessibilityHint("Opens Coach with the program builder and your current plan context")
                    Button {
                        jumpToTodayMonth()
                    } label: {
                        Label("Today", systemImage: "sun.max.fill")
                    }
                    .accessibilityHint("Shows the month containing today")
                }
            }
            .sheet(item: Binding(
                get: { daySheetDate.map { DaySheetItem(date: $0) } },
                set: { daySheetDate = $0?.date }
            )) { item in
                DayPlanSheet(date: item.date)
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
            }
            .sheet(item: Binding(
                get: { weekEditAnchor.map { WeekSheetItem(anchor: $0) } },
                set: { weekEditAnchor = $0?.anchor }
            )) { item in
                WeekOverrideSheet(weekContaining: item.anchor)
                    .environment(dataVM)
            }
            .sheet(isPresented: $showProgramBuilder) {
                ProgramBuilderSheet(
                    onBuildProgram: {
                        showProgramBuilder = false
                        openCoachDynamicProgramBuilderWithPlanContext()
                    },
                    onViewActiveProgram: {
                        showProgramBuilder = false
                        showActiveProgramDetail = true
                    }
                )
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
            }
            .sheet(isPresented: $showActiveProgramDetail) {
                ActiveProgramDetailView()
                    .environment(dataVM)
                    .environment(currentVM)
                    .environmentObject(aiService)
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

    private func openCoachDynamicProgramBuilderWithPlanContext() {
        FitlogHaptics.lightImpact()
        coachDeepLink.wrappedValue = .openDynamicProgramBuilder(prefill: dataVM.planCycleContextLineForCoach())
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

    @ViewBuilder
    private var dynamicProgramStatusBanner: some View {
        if let dyn = dataVM.dynamicProgramState {
            let pe = PeriodizationEngine(calendar: calendar)
            let today = calendar.startOfDay(for: Date())
            let placement = pe.blockPlacement(on: today, state: dyn)
            Button {
                FitlogHaptics.lightImpact()
                showActiveProgramDetail = true
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dynamic program")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(dyn.program.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if dyn.program.blocks.count > 1, let placement {
                            Text("Block \(placement.index + 1) of \(dyn.program.blocks.count) · Week \(placement.weekInBlock + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    Text("\(dyn.program.blocks.count) blocks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(dynamicProgramBannerAccessibility(dyn: dyn, placement: placement))
            .accessibilityHint("Opens your active program details")
        }
    }

    private func dynamicProgramBannerAccessibility(dyn: DynamicProgramState, placement: (index: Int, block: ProgramBlock, weekInBlock: Int)?) -> String {
        var parts = ["Dynamic program", dyn.program.name, "\(dyn.program.blocks.count) blocks"]
        if dyn.program.blocks.count > 1, let placement {
            parts.append("Block \(placement.index + 1) of \(dyn.program.blocks.count), week \(placement.weekInBlock + 1)")
        }
        return parts.joined(separator: ", ")
    }

    private func previousGridDate(from index: Int, daysInGrid: [Date?]) -> Date? {
        guard index > 0 else { return nil }
        for j in stride(from: index - 1, through: 0, by: -1) {
            if let d = daysInGrid[j] { return d }
        }
        return nil
    }

    /// Subtle tint for calendar cells inside a dynamic-program block (multi-block programs).
    private func dynamicCalendarBlockAccent(for date: Date) -> Color? {
        guard let dyn = dataVM.dynamicProgramState, dyn.program.blocks.count > 1 else { return nil }
        let pe = PeriodizationEngine(calendar: calendar)
        guard let placement = pe.blockPlacement(on: date, state: dyn) else { return nil }
        let palette: [Color] = [.orange, .mint, .indigo, .pink, .teal]
        return palette[abs(placement.block.id.hashValue) % palette.count]
    }

    /// Accent + label when a new program block starts relative to the previous visible grid cell (multi-block programs only).
    private func dynamicBlockBoundary(at date: Date, gridIndex: Int, daysInGrid: [Date?]) -> (accent: Color, blockName: String)? {
        guard let dyn = dataVM.dynamicProgramState, dyn.program.blocks.count > 1 else { return nil }
        let pe = PeriodizationEngine(calendar: calendar)
        guard let current = pe.blockPlacement(on: date, state: dyn) else { return nil }
        guard let prevDate = previousGridDate(from: gridIndex, daysInGrid: daysInGrid) else { return nil }
        guard let previous = pe.blockPlacement(on: prevDate, state: dyn) else { return nil }
        guard previous.block.id != current.block.id else { return nil }
        let palette: [Color] = [.orange, .mint, .indigo, .pink, .teal]
        let accent = palette[abs(current.block.id.hashValue) % palette.count]
        return (accent, current.block.name)
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
            ForEach(Array(days.enumerated()), id: \.offset) { offset, cell in
                if let date = cell {
                    dayCell(date: date, gridIndex: offset, daysInGrid: days)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(8)
    }

    private func dayCell(date: Date, gridIndex: Int, daysInGrid: [Date?]) -> some View {
        let resolved = cachedResolve(date: date)
        let isToday = calendar.isDateInToday(date)
        let isPastDay = calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
        let subtitle = dayPlanSubtitle(date: date, resolved: resolved)
        let status = dayStatus(date: date, resolved: resolved)
        let blockBoundary = dynamicBlockBoundary(at: date, gridIndex: gridIndex, daysInGrid: daysInGrid)
        let blockAccent = dynamicCalendarBlockAccent(for: date)

        return VStack(alignment: .leading, spacing: 4) {
            if let boundary = blockBoundary {
                Text(boundary.blockName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(boundary.accent)
                    .lineLimit(1)
                    .accessibilityLabel("Block \(boundary.blockName) starts")
            }
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
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemGroupedBackground))
                if let blockAccent {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(blockAccent.opacity(0.07))
                }
                if isToday {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.08))
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isToday ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: isToday ? 1.5 : 0)
        )
        .overlay(alignment: .leading) {
            if let boundary = blockBoundary {
                RoundedRectangle(cornerRadius: 2)
                    .fill(boundary.accent)
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .accessibilityHidden(true)
            }
        }
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
    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var swapPlanRef: WorkoutPlanRef?
    @State private var pendingWorkoutReplace: PendingWorkoutReplace?
    @State private var showMoveWorkoutPicker = false
    @State private var moveTargetDate = Date()
    @State private var showMoveReplaceConfirm = false
    @State private var pendingMoveTargetDate: Date?
    @State private var moveWorkoutFeedbackSerial = 0

    private var calendar: Calendar { .current }
    private var dayKey: String { TrainingProgramState.dayKey(for: date, calendar: calendar) }

    var body: some View {
        @Bindable var dm = dataVM
        return NavigationStack {
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

                if dm.dynamicProgramState != nil,
                   calendar.startOfDay(for: date) >= calendar.startOfDay(for: Date()) {
                    Section("Dynamic program") {
                        Toggle(
                            "Low availability (busy day)",
                            isOn: Binding(
                                get: { dm.dynamicProgramState?.busyDayKeys.contains(dayKey) ?? false },
                                set: { dm.setDynamicProgramBusyDay(dayKey: dayKey, isBusy: $0) }
                            )
                        )
                        .accessibilityHint("Marks this day as lower time so your periodized plan can compress, shift, or swap sessions based on your busy-day policy.")

                        if let pol = dm.dynamicProgramState?.program.busyDayPolicy {
                            Text(dynamicProgramBusyPolicyFootnote(pol))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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

                if case .workout(let ref) = dataVM.resolvedScheduleDay(for: date, calendar: calendar),
                   let planned = dataVM.workout(id: ref.libraryWorkoutId),
                   !planned.exercises.isEmpty {
                    Section("Exercises") {
                        ForEach(planned.exercises) { row in
                            dayPlanExerciseRow(row)
                        }
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

                        if case .workout = dataVM.resolvedScheduleDay(for: date, calendar: calendar) {
                            Button("Move to another day…") {
                                let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? date
                                moveTargetDate = max(tomorrow, calendar.startOfDay(for: date))
                                showMoveWorkoutPicker = true
                            }
                            .accessibilityHint("Reschedules this workout to a different day and marks this day as rest.")
                        }
                    }
                }

                Section {
                    if let wid = planWorkoutIdForLink {
                        NavigationLink("Open workout") {
                            if let binding = $dm.userWorkouts[wid] {
                                WorkoutPlanView(workout: binding, currentVM: currentVM)
                                    .environment(dataVM)
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
            .sheet(isPresented: $showMoveWorkoutPicker) {
                moveWorkoutDatePickerSheet
            }
            .confirmationDialog(
                "Replace existing workout?",
                isPresented: $showMoveReplaceConfirm,
                titleVisibility: .visible
            ) {
                Button("Replace and move", role: .destructive) {
                    if let target = pendingMoveTargetDate {
                        performMoveWorkout(to: target)
                    }
                    pendingMoveTargetDate = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingMoveTargetDate = nil
                }
            } message: {
                if let target = pendingMoveTargetDate {
                    Text(moveReplaceConfirmationMessage(for: target))
                }
            }
            .sensoryFeedback(.success, trigger: moveWorkoutFeedbackSerial)
        }
        .presentationDetents([.medium, .large])
    }

    private var moveWorkoutDatePickerSheet: some View {
        let todayStart = calendar.startOfDay(for: Date())
        let sourceStart = calendar.startOfDay(for: date)
        return NavigationStack {
            Form {
                if case .workout(let ref) = dataVM.resolvedScheduleDay(for: date, calendar: calendar) {
                    Section {
                        Text("Move \(dataVM.planLabel(for: ref)) from this day to another date. This day becomes a rest day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("This is a one-off day swap for this week—it does not permanently reorder your program rotation.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Section("New day") {
                    DatePicker(
                        "Target date",
                        selection: $moveTargetDate,
                        in: todayStart...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .accessibilityLabel("Target date for moved workout")
                }
            }
            .navigationTitle("Move workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMoveWorkoutPicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        requestMoveWorkout(to: moveTargetDate, sourceStart: sourceStart)
                    }
                    .disabled(calendar.isDate(moveTargetDate, inSameDayAs: sourceStart))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func requestMoveWorkout(to targetDate: Date, sourceStart: Date) {
        guard !calendar.isDate(targetDate, inSameDayAs: sourceStart) else { return }
        if targetDayHasWorkout(targetDate) {
            pendingMoveTargetDate = targetDate
            showMoveReplaceConfirm = true
        } else {
            performMoveWorkout(to: targetDate)
        }
    }

    private func targetDayHasWorkout(_ targetDate: Date) -> Bool {
        if case .workout = dataVM.resolvedScheduleDay(for: targetDate, calendar: calendar) {
            return true
        }
        return false
    }

    private func moveReplaceConfirmationMessage(for targetDate: Date) -> String {
        let label: String
        switch dataVM.resolvedScheduleDay(for: targetDate, calendar: calendar) {
        case .workout(let ref):
            label = dataVM.planLabel(for: ref)
        default:
            label = "the existing assignment"
        }
        let dateText = targetDate.formatted(date: .abbreviated, time: .omitted)
        return "\(dateText) already has \(label). Moving here will replace that assignment."
    }

    private func performMoveWorkout(to targetDate: Date) {
        guard case .workout(let ref) = dataVM.resolvedScheduleDay(for: date, calendar: calendar) else { return }
        let targetKey = TrainingProgramState.dayKey(for: targetDate, calendar: calendar)
        dataVM.setTrainingDayOverride(dayKey: targetKey, intent: .workout, planRef: ref)
        dataVM.setTrainingDayOverride(dayKey: dayKey, intent: .rest)
        moveWorkoutFeedbackSerial += 1
        showMoveWorkoutPicker = false
        dismiss()
    }

    private func dynamicProgramBusyPolicyFootnote(_ policy: BusyDayPolicy) -> String {
        switch policy {
        case .compress:
            return "Busy training days become rest; other sessions in the same week may absorb a little extra volume."
        case .shift:
            return "Busy training days become rest and the active block can extend so you don’t lose the whole phase."
        case .flexDay:
            return "Busy training days swap to a lighter flex template when possible."
        case .skip:
            return "Busy training days become rest; the rotation stays on the default cadence."
        }
    }

    private var planWorkoutIdForLink: UUID? {
        switch dataVM.resolvedScheduleDay(for: date, calendar: calendar) {
        case .workout(let ref):
            return ref.libraryWorkoutId
        default:
            return nil
        }
    }

    @ViewBuilder
    private func dayPlanExerciseRow(_ row: WorkoutExercise) -> some View {
        let resolvedModality = row.exerciseId.flatMap { id in
            dataVM.globalExercises.first { $0.id == id }?.modality
        }
        let isCardio = row.effectiveCardioPrescription != nil
            || resolvedModality == .cardio
            || resolvedModality == .hybrid

        if isCardio, let rx = row.effectiveCardioPrescription {
            let exercise = row.exerciseId.flatMap { id in dataVM.globalExercises.first { $0.id == id } }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(FitlogPalette.chartSecondary)
                    Text(dataVM.displayName(for: row))
                        .font(.subheadline.weight(.semibold))
                }
                CardioPrescriptionRowView(prescription: rx, exercise: exercise)
            }
            .padding(.vertical, 4)
            .listRowBackground(FitlogPalette.chartSecondary.opacity(0.08))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Cardio, \(dataVM.displayName(for: row)), \(CardioMetricsCalculator.prescriptionSummary(rx))")
        } else {
            HStack {
                Text(dataVM.displayName(for: row))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(row.recommendedSets)×\(row.recommendedReps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(dataVM.displayName(for: row)), \(row.recommendedSets) sets, \(row.recommendedReps) reps")
        }
    }
}

// MARK: - Week override sheet

struct WeekOverrideSheet: View {
    @Environment(DataManager.self) var dataVM
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
    @Environment(DataManager.self) var dataVM

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

// MARK: - Program builder (schedule + training order)

struct ProgramBuilderSheet: View {
    var onBuildProgram: () -> Void
    /// When set, shown as a quick action while a dynamic program is active (Plan tab).
    var onViewActiveProgram: (() -> Void)? = nil

    @Environment(DataManager.self) var dataVM
    @Environment(CurrentWorkoutSessionViewModel.self) var currentVM
    @EnvironmentObject var aiService: AIService
    @Environment(\.dismiss) private var dismiss

    @State private var sessionsPerWeek: Int = 3
    @State private var selectedWeekdays: Set<Int> = []
    @State private var anchorDate: Date = Date()
    @State private var showClearCycleConfirm = false
    @State private var clearedRotationUndo: [WorkoutPlanRef]?
    @State private var clearRotationUndoTask: Task<Void, Never>?

    private var program: TrainingProgramState { dataVM.trainingProgram }

    private var hasActiveDynamicProgram: Bool { dataVM.dynamicProgramState != nil }

    var body: some View {
        NavigationStack {
            List {
                if hasActiveDynamicProgram, program.cycleEntries.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(
                                "Your generated program controls this lineup on the calendar.",
                                systemImage: "rectangle.stack.fill"
                            )
                            .font(.subheadline)
                            Text("Open Program builder to change phases, templates, or regenerate.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                dismiss()
                                onBuildProgram()
                            } label: {
                                Label("Open program builder", systemImage: "calendar.badge.clock")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint("Opens Coach to edit your generated program")
                        }
                    } header: {
                        Text("Program lineup")
                    }
                } else if program.cycleEntries.isEmpty, !dataVM.userWorkouts.isEmpty {
                    Section {
                        Label(
                            "Add workouts to the list below so the calendar knows what to schedule on training days.",
                            systemImage: "calendar.badge.plus"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } header: {
                        Text("Set up your week")
                    }
                }

                Section {
                    Stepper("Strength days per week: \(sessionsPerWeek)", value: $sessionsPerWeek, in: 1...7)
                        .onChange(of: sessionsPerWeek) { _, n in
                            dataVM.setTrainingSessionsPerWeek(n)
                        }
                    Text("Optional: tap days you prefer. Leave none selected to use Monday–Friday as training-day options.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    programBuilderWeekdayGrid
                    DisclosureGroup("Advanced") {
                        DatePicker("Plan start reference", selection: $anchorDate, displayedComponents: .date)
                            .onChange(of: anchorDate) { _, d in
                                dataVM.setTrainingAnchorDate(d)
                            }
                        Text("The reference date aligns your workout order with the calendar. Change it if defaults feel “off” after a vacation or schedule change.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Your week")
                }

                Section {
                    if hasActiveDynamicProgram, let onView = onViewActiveProgram {
                        Button {
                            dismiss()
                            onView()
                        } label: {
                            Label("View active program", systemImage: "rectangle.stack.badge.checkmark")
                        }
                        .accessibilityHint("Shows your applied program, schedule, and templates")
                    }
                    Button {
                        dismiss()
                        onBuildProgram()
                    } label: {
                        Label("Open program builder", systemImage: "calendar.badge.clock")
                    }
                    .accessibilityHint("Opens Coach to build a single- or multi-phase program with AI or local presets")
                } header: {
                    Text("Quick actions")
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
                    Text(programBuilderTrainingDayOrderHeader)
                } footer: {
                    Text(programBuilderTrainingDayOrderFooter)
                        .font(.caption)
                }

                Section("Add to your lineup") {
                    let inCycle: (UUID) -> Bool = { wid in
                        program.cycleEntries.contains { $0 == .workout(wid) }
                    }
                    if dataVM.userWorkouts.allSatisfy({ inCycle($0.id) }) {
                        Text("Every saved workout is already in the lineup. Duplicate a step above to repeat a day.")
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
                    Button("Clear entire lineup", role: .destructive) {
                        showClearCycleConfirm = true
                    }
                    .disabled(program.cycleEntries.isEmpty)
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                syncScheduleStateFromProgram()
            }
            .onChange(of: dataVM.trainingProgram.anchorDayKey) { _, _ in
                syncScheduleStateFromProgram()
            }
            .confirmationDialog("Clear all workouts from your lineup?", isPresented: $showClearCycleConfirm, titleVisibility: .visible) {
                Button("Clear lineup", role: .destructive) {
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
                        Text("Lineup cleared")
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

    private var programBuilderTrainingDayOrderHeader: String {
        let n = program.cycleEntries.count
        if hasActiveDynamicProgram {
            return "Training day order (\(n)) — from your program"
        }
        return "Training day order (\(n))"
    }

    private var programBuilderTrainingDayOrderFooter: String {
        if hasActiveDynamicProgram {
            return "This lineup mirrors your generated program’s current block. Use Program builder in Coach for block-level changes; you can still reorder or duplicate days here for the repeating rotation."
        }
        return "This is the repeating lineup (e.g. Push → Pull → Legs). Open a row to edit exercises. Duplicate adds another step."
    }

    private func syncScheduleStateFromProgram() {
        sessionsPerWeek = program.sessionsPerWeek
        selectedWeekdays = Set(program.preferredWeekdays)
        if let d = TrainingProgramState.date(fromDayKey: program.anchorDayKey) {
            anchorDate = d
        }
    }

    private var programBuilderWeekdayGrid: some View {
        let days: [(Int, String)] = [
            (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
            (5, "Thu"), (6, "Fri"), (7, "Sat")
        ]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
            ForEach(days, id: \.0) { wd, label in
                let on = selectedWeekdays.contains(wd)
                Button {
                    if on { selectedWeekdays.remove(wd) } else { selectedWeekdays.insert(wd) }
                    dataVM.setTrainingPreferredWeekdays(Array(selectedWeekdays).sorted())
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

    @ViewBuilder
    private func workoutEditorDestination(for entry: WorkoutPlanRef) -> some View {
        @Bindable var dm = dataVM
        switch entry {
        case .workout(let id):
            if let binding = $dm.userWorkouts[id] {
                WorkoutPlanView(workout: binding, currentVM: currentVM)
                    .environment(dataVM)
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
                Text("Next in your cycle")
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
