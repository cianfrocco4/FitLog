//
//  PeriodizationEngine.swift
//  FitLog
//
//  Resolves which program block and rotation template apply on a calendar day.
//  Pure logic (no persistence); mirrors `TrainingScheduleEngine` weekday selection.
//

import Foundation

struct PeriodizationEngine: Sendable {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: - Block span

    /// Calendar days the block spans from its start (includes `blockShiftDays` extension).
    func effectiveBlockLengthDays(for block: ProgramBlock, state: DynamicProgramState) -> Int {
        let shiftDays = max(0, state.blockShiftDays[block.id] ?? 0)
        return block.durationWeeks * 7 + shiftDays
    }

    /// Start of the `blockIndex` block on the program timeline (start-of-day).
    func blockStartDate(blockIndex: Int, state: DynamicProgramState) -> Date {
        let anchor = calendar.startOfDay(for: state.anchorDate)
        var cursor = 0
        for i in 0 ..< blockIndex {
            cursor += effectiveBlockLengthDays(for: state.program.blocks[i], state: state)
        }
        return calendar.date(byAdding: .day, value: cursor, to: anchor) ?? anchor
    }

    /// Last calendar day of the block (inclusive).
    func blockEndDate(blockIndex: Int, state: DynamicProgramState) -> Date {
        let start = blockStartDate(blockIndex: blockIndex, state: state)
        let len = effectiveBlockLengthDays(for: state.program.blocks[blockIndex], state: state)
        return calendar.date(byAdding: .day, value: max(0, len - 1), to: start) ?? start
    }

    /// Block index and block for `date`, plus zero-based week index inside that block.
    func blockPlacement(
        on date: Date,
        state: DynamicProgramState
    ) -> (index: Int, block: ProgramBlock, weekInBlock: Int)? {
        let anchor = calendar.startOfDay(for: state.anchorDate)
        let dayStart = calendar.startOfDay(for: date)
        guard dayStart >= anchor else { return nil }

        let dayOffset = calendar.dateComponents([.day], from: anchor, to: dayStart).day ?? 0
        var cursor = 0
        for (idx, block) in state.program.blocks.enumerated() {
            let span = effectiveBlockLengthDays(for: block, state: state)
            if dayOffset < cursor + span {
                let into = dayOffset - cursor
                let weekInBlock = into / 7
                return (idx, block, weekInBlock)
            }
            cursor += span
        }
        return nil
    }

    /// When `date` falls in a different block than the day keyed by `previousDayKey`.
    func blockTransitionEvent(
        previousDayKey: String?,
        on date: Date,
        state: DynamicProgramState
    ) -> BlockTransitionEvent? {
        guard let prevKey = previousDayKey,
              let prevDate = TrainingProgramState.date(fromDayKey: prevKey, calendar: calendar),
              let previous = blockPlacement(on: prevDate, state: state),
              let current = blockPlacement(on: date, state: state) else { return nil }
        guard previous.block.id != current.block.id else { return nil }
        return BlockTransitionEvent(
            previousBlockId: previous.block.id,
            newBlockId: current.block.id,
            dayKey: TrainingProgramState.dayKey(for: date, calendar: calendar)
        )
    }

    // MARK: - Template resolution

    /// Which `BlockWeeklyTemplate` applies on this date (before busy/flex overrides).
    func baseResolvedDay(
        on date: Date,
        state: DynamicProgramState
    ) -> ResolvedProgramTemplateDay {
        guard let placement = blockPlacement(on: date, state: state) else {
            return .unscheduled
        }
        let program = state.program
        let templates = placement.block.weeklyTemplates
        guard !templates.isEmpty else { return .unscheduled }

        guard isDefaultTrainingDay(date, sessionsPerWeek: program.defaultSessionsPerWeek, preferredWeekdays: program.preferredWeekdays) else {
            return .unscheduled
        }

        guard let templateIndex = cycleTemplateIndex(on: date, state: state, templatesCount: templates.count) else {
            return .unscheduled
        }

        let template = templates[templateIndex]
        return .training(template)
    }

    /// Applies busy-day policy on top of `baseResolvedDay`.
    func resolvedTemplateDay(on date: Date, state: DynamicProgramState) -> ResolvedProgramTemplateDay {
        let key = TrainingProgramState.dayKey(for: date, calendar: calendar)
        let base = baseResolvedDay(on: date, state: state)

        switch base {
        case .unscheduled, .rest:
            return base
        case .training(let template):
            if state.busyDayKeys.contains(key) {
                switch state.program.busyDayPolicy {
                case .flexDay:
                    return .flex(Self.flexVariant(from: template))
                case .compress, .shift, .skip:
                    return .rest
                }
            }
            // Compress: when a training day in this ISO week was marked busy, add a light volume bump to remaining sessions.
            if state.program.busyDayPolicy == .compress,
               compressVolumeActiveInWeek(containing: date, state: state) {
                return .training(Self.augmentSetsForCompress(template))
            }
            return base

        case .flex:
            return base
        }
    }

    /// True when at least one **default training day** in the same ISO week as `date` is marked busy (lost session that week).
    func compressVolumeActiveInWeek(containing date: Date, state: DynamicProgramState) -> Bool {
        let trainingKeys = trainingDayKeysInWeek(
            containing: date,
            sessionsPerWeek: state.program.defaultSessionsPerWeek,
            preferredWeekdays: state.program.preferredWeekdays
        )
        return trainingKeys.contains { state.busyDayKeys.contains($0) }
    }

    /// +1 working set per slot (capped) so remaining days absorb a bit of the missed busy-day volume.
    private static func augmentSetsForCompress(_ template: BlockWeeklyTemplate) -> BlockWeeklyTemplate {
        let slots = template.slots.map { slot -> SplitBuilderEditableSlot in
            let bumped = min(10, slot.sets + 1)
            return slot.updatingSets(bumped)
        }
        return BlockWeeklyTemplate(
            id: template.id,
            dayName: template.dayName,
            focus: template.focus,
            slots: slots,
            dayNotes: template.dayNotes
        )
    }

    /// Context for progression heuristics when `date` is a training day inside a block.
    func blockContext(on date: Date, state: DynamicProgramState) -> BlockContext? {
        guard let placement = blockPlacement(on: date, state: state) else { return nil }
        let resolved = resolvedTemplateDay(on: date, state: state)
        switch resolved {
        case .training, .flex:
            break
        case .rest, .unscheduled:
            return nil
        }
        let block = placement.block
        return BlockContext(
            blockId: block.id,
            focus: block.focus,
            volumeMultiplier: block.volumeMultiplier,
            progressionStrategy: block.progressionStrategy,
            weekIndexInBlock: placement.weekInBlock,
            isDeloadBlock: block.isDeloadBlock,
            blockDurationWeeks: block.durationWeeks
        )
    }

    // MARK: - Flex template

    /// ~50% sets, same structure; new template id for editing independence.
    static func flexVariant(from template: BlockWeeklyTemplate) -> BlockWeeklyTemplate {
        let slots = template.slots.map { slot -> SplitBuilderEditableSlot in
            let reduced = max(1, Int((Double(slot.sets) * 0.5).rounded(.up)))
            return slot.withNewSlotId().updatingSets(min(reduced, slot.sets))
        }
        let focus = template.focus.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = focus.isEmpty ? "Recovery" : "Recovery — \(focus)"
        // Reuse the template id so `materializedTemplateWorkoutIds` still resolves after busy-day flex.
        return BlockWeeklyTemplate(
            id: template.id,
            dayName: template.dayName + " (Flex)",
            focus: suffix,
            slots: slots,
            dayNotes: template.dayNotes
        )
    }

    // MARK: - Weekday / rotation (aligned with `TrainingScheduleEngine`)

    func trainingDayKeysInWeek(
        containing date: Date,
        sessionsPerWeek: Int,
        preferredWeekdays: [Int]
    ) -> Set<String> {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        var days: [Date] = []
        var d = interval.start
        while d < interval.end {
            days.append(calendar.startOfDay(for: d))
            d = calendar.date(byAdding: .day, value: 1, to: d) ?? interval.end
        }

        let candidateSet: Set<Int>
        if preferredWeekdays.isEmpty {
            candidateSet = [2, 3, 4, 5, 6]
        } else {
            candidateSet = Set(preferredWeekdays)
        }

        let n = min(max(1, sessionsPerWeek), 7)
        let trainingDates = days
            .filter { candidateSet.contains(calendar.component(.weekday, from: $0)) }
            .sorted { $0 < $1 }
        let picked = Array(trainingDates.prefix(n))
        return Set(picked.map { TrainingProgramState.dayKey(for: $0, calendar: calendar) })
    }

    func isDefaultTrainingDay(
        _ date: Date,
        sessionsPerWeek: Int,
        preferredWeekdays: [Int]
    ) -> Bool {
        let keys = trainingDayKeysInWeek(containing: date, sessionsPerWeek: sessionsPerWeek, preferredWeekdays: preferredWeekdays)
        let dk = TrainingProgramState.dayKey(for: date, calendar: calendar)
        return keys.contains(dk)
    }

    private func isCycleProgressDay(_ date: Date, state: DynamicProgramState) -> Bool {
        guard isDefaultTrainingDay(
            date,
            sessionsPerWeek: state.program.defaultSessionsPerWeek,
            preferredWeekdays: state.program.preferredWeekdays
        ) else { return false }
        let key = TrainingProgramState.dayKey(for: date, calendar: calendar)
        return !state.skippedProgramTrainingDayKeys.contains(key)
    }

    /// Ordinal training days from anchor through `date` (inclusive), counting only cycle-progress days.
    private func trainingDayOrdinal(on date: Date, state: DynamicProgramState) -> Int? {
        let anchorStart = calendar.startOfDay(for: state.anchorDate)
        let dateStart = calendar.startOfDay(for: date)
        guard dateStart >= anchorStart else { return nil }

        var ord = 0
        var walk = anchorStart
        while walk <= dateStart {
            if isCycleProgressDay(walk, state: state) {
                ord += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: walk) else { break }
            walk = next
        }
        return ord
    }

    /// Zero-based index into `weeklyTemplates` for this training day.
    func cycleTemplateIndex(on date: Date, state: DynamicProgramState, templatesCount: Int) -> Int? {
        guard templatesCount > 0 else { return nil }
        guard isDefaultTrainingDay(
            date,
            sessionsPerWeek: state.program.defaultSessionsPerWeek,
            preferredWeekdays: state.program.preferredWeekdays
        ) else { return nil }

        guard let ord = trainingDayOrdinal(on: date, state: state), ord > 0 else { return nil }
        let n = templatesCount
        let phase = 0
        let idx = ((ord - 1 + phase) % n + n) % n
        return idx
    }
}
