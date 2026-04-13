# UI/UX Bugfix Plan

Tracked issues from the `cursor/workout-entity-consolidation-and-ui-ux-streamlining-093f` branch.

---

## Issue 1: Keyboard for weight input in inline log set view can't be dismissed

### Symptom
The decimal/number pad keyboard that appears when tapping into the weight or reps fields in the inline "Log next set" row cannot be dismissed. This is inconsistent with every other keyboard in the app, which surfaces a "Done" button via `.keyboardDismissToolbar()`.

### Root Cause
The inline weight/reps `TextField`s in `CurrentWorkoutPullUpSheet.swift` use `.keyboardType(.decimalPad)` and `.keyboardType(.numberPad)`, which have no built-in Return key. The shared `.keyboardDismissToolbar()` modifier (from `Extensions.swift`) is applied at the sheet's `NavigationStack` level (line 888), but it may not propagate correctly to text fields nested deep inside `List` rows within a presented sheet. Additionally, there is no `@FocusState` tracking or `.scrollDismissesKeyboard` on the `List`, unlike `AIChatView` which uses both.

### Proposed Fix
1. **Add `@FocusState` tracking** to `CurrentWorkoutPullUpSheet` for the inline weight field, reps field, and edit-set fields. Bind each `TextField` to its focus case.
2. **Add `.scrollDismissesKeyboard(.interactively)`** to the `List` so swiping the list dismisses the keyboard (consistent with `AIChatView`).
3. **Verify toolbar propagation** — ensure `.keyboardDismissToolbar()` surfaces a "Done" button on the numeric keyboard within the sheet context. If toolbar nesting is the problem, apply it at the `NavigationStack` level or directly on the fields.
4. **Add a tap-to-dismiss gesture** on the surrounding card area outside the text fields, using the `@FocusState` to nil out focus.

### Files to Change
- `FitLog/CurrentWorkoutPullUpSheet.swift` — add `@FocusState`, `.scrollDismissesKeyboard`, verify toolbar placement
- `FitLog/Extensions.swift` — no changes expected; verify the modifier works in sheet contexts

### Risk: Low
Additive change, no data model impact.

---

## Issue 2: Inline log set weight and reps boxes are too small to tap

### Symptom
The weight and reps input boxes in the inline "Log next set" row are difficult to tap accurately, especially on smaller devices.

### Root Cause
The weight field has `frame(minWidth: 44)` with `padding(8)`, and the reps field has `frame(minWidth: 40)` with `padding(8)`. The resulting tap target is roughly 44–60pt wide by ~36pt tall — below Apple's recommended 44×44pt minimum. The fields are packed into a single `HStack(spacing: 8)` alongside the unit label, "×" separator, "Log" button, and "+ RPE / drops" button. The edit-set row (`interactiveLoggedSetRow`) is even tighter with `minWidth: 36` for reps.

### Proposed Fix
1. **Increase minimum widths**: weight to `minWidth: 60`, reps to `minWidth: 52`. Edit-set reps from 36 to at least 48.
2. **Increase padding** from `padding(8)` to `padding(.horizontal, 12)` and `padding(.vertical, 10)` for a larger touch target (at least 44pt tall).
3. **Add explicit minimum height**: `.frame(minHeight: 44)` on each input field.
4. **Consider a two-row layout** for the controls: weight + reps on one row, action buttons on a second row. This gives the fields more horizontal room and makes the overall card less cramped. A `VStack` with two `HStack`s is the simplest approach.
5. **Apply the same sizing improvements** to the edit-set row (`interactiveLoggedSetRow`).

### Files to Change
- `FitLog/CurrentWorkoutPullUpSheet.swift`
  - `inlineSetEntryRow` (lines 1251–1290)
  - `interactiveLoggedSetRow` (lines 1365–1410)

### Risk: Low
Visual-only change. Test on multiple device sizes (SE, standard, Pro Max).

---

## Issue 3: Exercise history data missing

### Symptom
Two sub-issues:
- **3a.** The active workout view does not show "last time logged" sets for an exercise (the "Last time for this exercise" section is absent).
- **3b.** The History tab's Explore view shows no data in the "By exercise" category.

### Root Cause

**3a — "Last time" not appearing:**
`lastCompletedLog(for:)` in `CurrentWorkoutPullUpSheet.swift` (line ~1807) requires `currentLog.workoutExercise.exerciseId` to be non-nil. For exercises added via flexible/open-slot plans, or exercises where the `WorkoutExercise` was created before the `exerciseId` field existed, this function returns `nil` and the "Last time" section never renders. The function also depends on `dataVM.completedSessions`, which relies on `SessionStore.loadSessions()` decoding `SDWorkoutSession` records — any session that fails to decode is silently dropped via `compactMap { $0.toStruct() }`.

**3b — "By exercise" analytics empty:**
`exerciseStats(in:)` in `HistoryView.swift` (line 1327) iterates `filteredSessions` and for each `ExerciseLog`, calls `dataVM.resolveExercise(for: snap)`. If `workoutExercise.snapshot` is nil, the `guard let snap` check skips that exercise entirely, making it invisible to analytics. Additionally, `filteredSessions` depends on the selected date range (`dayRange`) — if the default range is narrow, older sessions are excluded.

### Proposed Fix
1. **Add `exerciseId`-based fallback** in `exerciseStats(in:)`:
   ```swift
   // Instead of only:
   guard let snap = log.workoutExercise.snapshot,
         let ex = dataVM.resolveExercise(for: snap) else { continue }
   // Also try:
   if snap == nil, let eid = log.workoutExercise.exerciseId,
      let ex = dataVM.globalExercises.first(where: { $0.id == eid }) { ... }
   ```
2. **Same fallback in `ExerciseHistoryDetailView.sessionLogs`** for the `first(where:)` filter.
3. **In `lastCompletedLog(for:)`**: add fallback resolution when `exerciseId` is nil but `snapshot` exists (resolve snapshot → get exercise ID).
4. **Audit snapshot population**: ensure that when a session is saved/completed via `CurrentWorkoutSessionViewModel`, every `ExerciseLog`'s `workoutExercise` has a non-nil `snapshot`.
5. **Add debug logging** for `SDWorkoutSession.toStruct()` decode failures to detect silent data drops.
6. **Verify default date range**: check what `dayRange` defaults to. If it's too narrow (e.g. 30 days), consider a wider default ("All time" or "6 months") on the Explore tab.

### Files to Change
- `FitLog/HistoryView.swift` — `exerciseStats(in:)`, `ExerciseHistoryDetailView.sessionLogs`
- `FitLog/CurrentWorkoutPullUpSheet.swift` — `lastCompletedLog(for:)`
- `FitLog/CurrentWorkoutSessionViewModel.swift` — session completion logic (ensure snapshots populated)
- `FitLog/Models.swift` — verify `WorkoutExercise` snapshot logic

### Risk: Medium
Changes touch data resolution logic. Must not break existing data display; needs testing with real session data (both old and new formats).

---

## Issue 4: "Top muscles by set" flickering every second during active workout

### Symptom
The "Top muscles (by sets)" row in the workout Overview section (`WorkoutPlanView`) visually updates/flickers every second while a workout session is active. This does not happen when no session is running.

### Root Cause
`WorkoutPlanView` declares `@EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel` (line 51). `CurrentWorkoutSessionViewModel` runs two timers:
- **Workout timer** — updates `@Published var workoutElapsedSeconds` every 1 second (lines 199–210)
- **Rest timer** — updates `@Published var remainingRestTime` every 1 second (lines 587–624)

Every `@Published` change invalidates **all** views observing `currentVM`, including `WorkoutPlanView`. This forces the entire view body to re-evaluate each second, including the `workoutPrimaryMuscleSummary` computed property. While the string value is deterministic, the re-render causes visual flickering in the `LabeledContent` row.

The codebase already acknowledges this problem — `AddExerciseSheet` (line 951–954) explicitly passes `currentVM` as a `let` parameter instead of `@EnvironmentObject` to avoid timer-driven re-renders:

```swift
/// Passed in so the sheet doesn't observe it; avoids timer-driven
/// re-renders that reset scroll position.
let currentVM: CurrentWorkoutSessionViewModel
```

### Proposed Fix
**Option A (recommended — matches existing codebase pattern):**
Change `WorkoutPlanView`'s `@EnvironmentObject var currentVM: CurrentWorkoutSessionViewModel` to a passed-in `let currentVM: CurrentWorkoutSessionViewModel` parameter. Update all call sites that create `WorkoutPlanView` to pass it explicitly. This breaks the `@Published` observation chain so timer ticks no longer invalidate the plan view.

**Option B (longer-term architectural):**
Refactor `CurrentWorkoutSessionViewModel` to move timer-only state (`workoutElapsedSeconds`, `remainingRestTime`) into a separate `@Observable` object. Only views that display the timer would subscribe. More invasive but prevents the problem globally for all future views.

### Files to Change
- `FitLog/WorkoutPlanView.swift` — change `@EnvironmentObject var currentVM` to `let currentVM`
- All call sites that push/present `WorkoutPlanView`:
  - `FitLog/HomeView.swift`
  - `FitLog/PlanCalendarView.swift` (if applicable)
  - Any other file that instantiates `WorkoutPlanView`

### Risk: Low–Medium
Must update every call site correctly. Compiler will catch missing arguments.

---

## Issue 5: "Search Workouts" at the top of Home page feels disconnected

### Symptom
The search bar labeled "Search workouts" / "Search all workouts" appears in the navigation bar at the very top of the Home screen, but the workout list it filters is the last section in the page — below the today dashboard, progress summary, weekly recap, program assignment banner, and Program/AI split section. Users must scroll 1–2 pages to reach the content the search filters.

### Root Cause
`HomeView` applies `.searchable(text: $workoutSearchText, prompt: ...)` on the `NavigationStack` (line 360). SwiftUI renders this in the navigation bar area. The `List` body renders sections in this order:
1. Active workout card + today dashboard + progress + weekly recap
2. Program assignment banner (optional)
3. Program / AI split section
4. **"Your workouts"** section (last)

### Proposed Fix

**Option A — Remove top-level search when in preview mode:**
When `homeShowsWorkoutPreviewOnly` is true (user has many workouts), remove the navigation-level `.searchable` modifier entirely. Users who want to search tap the existing "All workouts" `NavigationLink`, which pushes `HomeWorkoutLibraryView` — a dedicated screen with its own `.searchable`. This keeps the Home page as a clean dashboard.

**Option B — Move search into the workouts section:**
Remove `.searchable` from the navigation level. Add a `TextField` styled as a search bar directly inside or above the "Your workouts" section header. This co-locates search with the content it filters.

**Option C — Move the workout section higher:**
Reorder sections so "Your workouts" appears right after the today dashboard, before the program sections.

**Recommendation:** Option A is the simplest and cleanest. Home becomes a dashboard (stats + workout preview), and full search lives in the dedicated "All workouts" screen. When the user has few workouts (no preview mode), the nav-level search can remain since scrolling distance is minimal.

### Files to Change
- `FitLog/HomeView.swift` — conditionally apply `.searchable` based on `homeShowsWorkoutPreviewOnly`

### Risk: Low
UI change only, no data impact.

---

## Issue 6: Adding a new custom exercise is buried (requires More tab)

### Symptom
To create a new custom exercise from the Home tab, a user must: (1) tap the More tab, (2) tap "Exercise Library", (3) tap "Add New" — 3 taps through screens that aren't part of the main workout flow. While exercise creation is available during an active workout (Add Exercise → New Custom) and during workout planning (via the More menu), there is no shortcut from the Home tab.

### Root Cause
`HomeView`'s trailing toolbar `Menu` only offers "New workout", "Build split with AI", and "Sign Out". There is no entry point to the Exercise Library or custom exercise creation from Home. The `ExercisesLibraryView` is only reachable from `MoreTabRootView`.

### Proposed Fix
1. **Add "Exercise Library" to the Home toolbar menu.** Add a button/link in the existing `+` menu that navigates to `ExercisesLibraryView`. This provides one-tap access from Home.
2. **Add "New Exercise" to the Home toolbar menu.** Add a button that directly presents `NewExerciseSheet`. This makes custom exercise creation a single tap from Home.
3. **Optionally add a "Quick Actions" row** on the Home page (between dashboard and workouts) with shortcuts to frequently used features: Exercise Library, New Exercise, etc.

**Recommendation:** Adding both "Exercise Library" and "New exercise" to the existing Home `+` menu is the lightest-touch change. It takes custom exercise creation from 3 taps to 1–2 taps for the most common entry point.

### Files to Change
- `FitLog/HomeView.swift` — add menu items to the trailing toolbar `Menu`, add `@State` for `NewExerciseSheet` presentation, add `.sheet` modifier, optionally add `NavigationLink` destination for `ExercisesLibraryView`

### Risk: Low
Additive change, no data model impact.

---

## Summary

| # | Issue | Files | Invasiveness | Risk |
|---|-------|-------|-------------|------|
| 1 | Keyboard can't be dismissed | `CurrentWorkoutPullUpSheet.swift` | Low–Medium | Low |
| 2 | Small tap targets on inline inputs | `CurrentWorkoutPullUpSheet.swift` | Low | Low |
| 3 | Exercise history data missing | `HistoryView.swift`, `CurrentWorkoutPullUpSheet.swift`, `CurrentWorkoutSessionViewModel.swift`, `Models.swift` | Medium | Medium |
| 4 | Muscle summary flickering | `WorkoutPlanView.swift` + call sites | Medium | Low–Medium |
| 5 | Search bar disconnected from workouts | `HomeView.swift` | Low | Low |
| 6 | Custom exercise creation buried | `HomeView.swift` | Low | Low |
