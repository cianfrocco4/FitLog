# FitLog Improvement Suggestions

Analysis of the `2026-03-24-4d4m` branch (11 commits, ~3,000 lines across 23 files). These suggestions cover data modeling, UI/UX, and architecture.

---

## Data Modeling

### 1. Migrate off UserDefaults to a real persistence layer

**Problem**

Every model (`Workout`, `WorkoutTemplate`, `WorkoutSession`) is JSON-encoded into `UserDefaults`. The branch adds two new top-level collections (`userWorkoutTemplates`, growing `completedSessions`). `UserDefaults` is backed by a single plist that is atomically read and written on every save. As data volumes grow this causes:

- **Data loss risk**: simultaneous writes from foreground and background (notification extension, widget) can corrupt the plist.
- **Performance degradation**: every `saveWorkoutTemplates()` or `saveSessions()` serializes the entire collection.
- **No indexing**: `hasCompletedSessionEnding(on:)` and `completedSessionCount(inWeekContaining:)` do a full linear scan of all sessions on every call, and they are called per-day in the week strip (7 times).

**How to implement**

1. Add a SwiftData `ModelContainer` to the app entry point with a shared `ModelContext`.
2. Convert each top-level struct (`Workout`, `WorkoutTemplate`, `WorkoutSession`, `Exercise`) into a `@Model` class. Keep the existing structs as lightweight DTOs for encoding/decoding if needed during migration.
3. Replace the `UserDefaults` load/save pairs in `DataManager` with `ModelContext` fetch and insert calls.
4. Add a one-time migration path: on first launch after the update, read the existing `UserDefaults` data, insert it into the SwiftData store, then delete the `UserDefaults` keys.
5. Add indexes on frequently queried fields:
   - `WorkoutSession.endTime` (used by every analytics query).
   - `WorkoutSession.sessionPlanOrigin` (used by the new History filter).
   - `Exercise.name` (used by case-insensitive lookups in AI proposal application).
6. Replace the linear-scan helper methods with SwiftData `#Predicate` fetch descriptors:

```swift
// Before (linear scan):
private func hasCompletedSessionEnding(on dayStart: Date, calendar: Calendar) -> Bool {
    let start = calendar.startOfDay(for: dayStart)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
    return completedSessions.contains { session in
        guard let end = session.endTime else { return false }
        return end >= start && end < dayEnd
    }
}

// After (indexed fetch):
private func hasCompletedSessionEnding(on dayStart: Date, calendar: Calendar) -> Bool {
    let start = calendar.startOfDay(for: dayStart)
    guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
    let descriptor = FetchDescriptor<WorkoutSessionModel>(
        predicate: #Predicate { $0.endTime != nil && $0.endTime! >= start && $0.endTime! < dayEnd },
        fetchLimit: 1
    )
    return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
}
```

7. Remove all manual `Codable` conformances (~150 lines in `Models.swift`) since SwiftData handles persistence automatically.

**Files to change**: `Models.swift`, `DataManager.swift`, `FitLogApp.swift` (or equivalent entry point), plus a new `MigrationService.swift`.

---

### 2. Separate WorkoutExercise from slot-placeholder concerns

**Problem**

`WorkoutExercise` now carries `isSlotPlaceholder`, `templateSlotId`, and `slotLabel`. The same struct represents a concrete exercise prescription in a saved `Workout`, a resolved-or-unresolved slot during a live session, and a placeholder that cannot have sets logged against it. This leaks slot-template concepts into code paths that should only deal with concrete exercises. The `logSet()` method has a runtime guard that should be a compile-time guarantee:

```swift
// CurrentWorkoutSessionViewModel.swift
guard !session.exerciseLogs[exerciseIndex].workoutExercise.isSlotPlaceholder else { return }
```

**How to implement**

1. Define a resolution enum on `WorkoutExercise`:

```swift
enum SlotResolution: Codable, Equatable {
    case concrete(Exercise)
    case unresolved(slotLabel: String, templateSlotId: UUID)
}
```

2. Replace the `exercise` property and the three slot fields with a single `resolution: SlotResolution`:

```swift
struct WorkoutExercise: Identifiable, Codable, Equatable {
    let id: UUID
    var resolution: SlotResolution
    var defaultRestTime: Int = 90
    var recommendedSets: Int = 3
    var recommendedReps: String = "8-12"
    var configurationFields: [String] = []
    var recommendedConfigBySet: [[String: String]] = []

    var resolvedExercise: Exercise? {
        if case .concrete(let ex) = resolution { return ex }
        return nil
    }

    var isSlotPlaceholder: Bool {
        if case .unresolved = resolution { return true }
        return false
    }
}
```

3. Update `resolveSlotPlaceholder` in `CurrentWorkoutSessionViewModel` to transition the enum case:

```swift
func resolveSlotPlaceholder(workoutExerciseId: UUID, exercise: Exercise) {
    guard var session = currentSession else { return }
    if let wi = session.workout.exercises.firstIndex(where: { $0.id == workoutExerciseId }) {
        session.workout.exercises[wi].resolution = .concrete(exercise)
    }
    if let li = session.exerciseLogs.firstIndex(where: { $0.workoutExercise.id == workoutExerciseId }) {
        session.exerciseLogs[li].workoutExercise.resolution = .concrete(exercise)
    }
    currentSession = session
    saveActiveSession()
}
```

4. Remove the runtime guard in `logSet()` — any call site that tries to log against an `.unresolved` slot will get a `nil` from `resolvedExercise` and the UI layer can handle it by not presenting the "Add New Set" button at all.

5. Add a backward-compatible `init(from decoder:)` that reads the old `exercise` + `isSlotPlaceholder` fields and maps them into the new `resolution` enum.

**Files to change**: `Models.swift`, `CurrentWorkoutSessionViewModel.swift`, `CurrentWorkoutPullUpSheet.swift`, `DataManager.swift` (instantiateWorkout), `LogSetView.swift`.

---

### 3. Stop embedding full Exercise objects in sessions

**Problem**

`WorkoutSession.workout` embeds a full copy of every `Exercise` (name, description, targetedMuscles, configurationOptions, exerciseRole, movementPattern) for every session. This means:

- If a user renames an exercise, old sessions display the stale name.
- Each completed session stores ~1–2 KB per exercise redundantly across all sessions.
- The new `exerciseRole` and `movementPattern` fields add to duplication without being used at the session level.

**How to implement**

1. Define a lightweight snapshot struct for historical records:

```swift
struct ExerciseSnapshot: Codable, Equatable, Hashable {
    let exerciseId: UUID
    let nameAtTimeOfLog: String
}
```

2. In `WorkoutExercise`, replace `var exercise: Exercise` with `var exerciseRef: ExerciseSnapshot` for the session-log context.
3. When creating a session from a workout, snapshot only the id and name:

```swift
let snapshot = ExerciseSnapshot(
    exerciseId: exercise.id,
    nameAtTimeOfLog: exercise.name
)
```

4. For display, resolve the full exercise from the global library when available, falling back to the snapshot name:

```swift
func displayName(for snapshot: ExerciseSnapshot) -> String {
    if let ex = globalExercises.first(where: { $0.id == snapshot.exerciseId }) {
        return resolvedDisplayName(for: ex)
    }
    return snapshot.nameAtTimeOfLog
}
```

5. Add a backward-compatible decoder that reads the old full `Exercise` object and extracts just the snapshot fields. On re-encode, write only the snapshot.

**Files to change**: `Models.swift` (add `ExerciseSnapshot`, update `WorkoutExercise`), `DataManager.swift` (session creation helpers), `HistoryView.swift` and `CurrentWorkoutPullUpSheet.swift` (display resolution).

---

### 4. Unify WorkoutPlanRef and ProgramCycleEntry

**Problem**

`WorkoutPlanRef` is an enum (`concreteWorkout(UUID)` / `slotTemplate(UUID)`). `ProgramCycleEntry` is a struct with `kind: ProgramCycleTargetKind` and `id: UUID`. These represent the same concept in two shapes. Code constantly maps between them:

```swift
// DataManager.swift
entries.append(ProgramCycleEntry(kind: .concreteWorkout, id: id))
// But sessions use:
sessionPlanOrigin: .concreteWorkout(id)
```

**How to implement**

1. Remove `ProgramCycleTargetKind` and `ProgramCycleEntry` entirely.
2. Use `WorkoutPlanRef` as the cycle entry type:

```swift
struct TrainingProgramState: Codable, Equatable {
    var cycleEntries: [WorkoutPlanRef]  // was [ProgramCycleEntry]
    // ...
}
```

3. Update `TrainingScheduleEngine.defaultCycleEntry` to return `WorkoutPlanRef?` directly.
4. Remove all mapping code in `DataManager` (`cycleWorkoutIds.map { ProgramCycleEntry(kind: .concreteWorkout, id: $0) }` etc.).
5. Add a backward-compatible decoder to `TrainingProgramState` that reads old `ProgramCycleEntry` JSON and converts to `WorkoutPlanRef`:

```swift
init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if let refs = try? c.decode([WorkoutPlanRef].self, forKey: .cycleEntries) {
        cycleEntries = refs
    } else if let legacy = try? c.decode([LegacyProgramCycleEntry].self, forKey: .cycleEntries) {
        cycleEntries = legacy.map { entry in
            switch entry.kind {
            case .concreteWorkout: return .concreteWorkout(entry.id)
            case .slotTemplate: return .slotTemplate(entry.id)
            }
        }
    } else {
        let legacyIds = (try? c.decode([UUID].self, forKey: .cycleWorkoutIds)) ?? []
        cycleEntries = legacyIds.map { .concreteWorkout($0) }
    }
    // ...
}
```

**Files to change**: `TrainingScheduleModels.swift`, `TrainingScheduleEngine.swift`, `DataManager.swift`, `PlanCalendarView.swift`, `HomeView.swift`, `AIService.swift`.

---

### 5. Add explicit schema versioning

**Problem**

Multiple models use fallback decoding (`(try? c.decode(...)) ?? defaultValue`) but there is no versioned schema. If a future change renames or removes a field the silent fallback will mask data corruption. The backup mechanism (`workoutsBackupKey`, `workoutTemplatesBackupKey`) only saves the first-ever encoding and never rotates.

**How to implement**

1. Define a version constant and wrap the top-level encoded payload:

```swift
struct VersionedPayload<T: Codable>: Codable {
    let schemaVersion: Int
    let data: T
}

// Current version
let currentSchemaVersion = 2
```

2. When saving, always wrap:

```swift
func saveWorkouts() {
    let payload = VersionedPayload(schemaVersion: currentSchemaVersion, data: userWorkouts)
    let data = try JSONEncoder().encode(payload)
    UserDefaults.standard.set(data, forKey: workoutsKey)
}
```

3. When loading, read the version and branch on it:

```swift
func loadWorkouts() {
    guard let raw = UserDefaults.standard.data(forKey: workoutsKey) else { return }
    if let versioned = try? JSONDecoder().decode(VersionedPayload<[Workout]>.self, from: raw) {
        switch versioned.schemaVersion {
        case 1:
            userWorkouts = migrateV1ToV2(versioned.data)
        case 2:
            userWorkouts = versioned.data
        default:
            // Future version from a newer app — attempt direct decode, log warning
            userWorkouts = versioned.data
        }
    } else {
        // Pre-versioning legacy data
        userWorkouts = (try? JSONDecoder().decode([Workout].self, from: raw)) ?? []
    }
}
```

4. Rotate backups: keep the last 2 known-good encodings and delete older ones.

**Files to change**: `DataManager.swift` (all load/save pairs), new `SchemaVersion.swift` or `MigrationService.swift`.

---

## UI/UX

### 6. Extract a reusable today-workout card component

**Problem**

The `todayPlanSuggestionCard` in `HomeView` handles `rest`, `unscheduled`, `concreteWorkout` (with sub-states: active, completed, startable, missing), and `slotTemplate` (same sub-states) all inline. The concrete and slot branches are nearly identical (~60 lines each) with the same button layouts.

**How to implement**

1. Create a new `TodayWorkoutCard` view:

```swift
struct TodayWorkoutCard: View {
    let title: String
    let subtitle: String
    let isCompleted: Bool
    let isInProgress: Bool
    let onStart: () -> Void
    let destination: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)

            if isInProgress {
                Text("Finish your current workout before starting another.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if isCompleted {
                Label("Completed today", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(.green)
                if let destination {
                    NavigationLink { destination } label: {
                        Label("View details", systemImage: "list.bullet")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button(action: onStart) {
                    Label("Start workout", systemImage: "play.fill")
                        .font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                if let destination {
                    NavigationLink { destination } label: {
                        Label("View details", systemImage: "list.bullet")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
```

2. Replace the two large switch branches in `todayPlanSuggestionCard` with calls to `TodayWorkoutCard`, configured with the appropriate parameters for each case.

3. Handle the "missing workout/template" case with a simpler inline fallback (no card needed).

**Files to change**: new `TodayWorkoutCard.swift`, `HomeView.swift` (reduce `todayPlanSuggestionCard` from ~140 lines to ~30).

---

### 7. Replace developer terminology with user-facing language

**Problem**

Users see labels like "Concrete workout", "Slot template . 3 slot(s)", "Concrete workout . from your training plan". These are implementation terms. Most users have no mental model for "concrete" vs "slot".

**How to implement**

1. Define a string constants file or extension with user-facing labels:

```swift
extension WorkoutPlanRef {
    var userFacingTypeLabel: String {
        switch self {
        case .concreteWorkout: return "Saved routine"
        case .slotTemplate: return "Flexible template"
        }
    }
}
```

2. Rename UI strings across the codebase:

| Current | Replacement |
|---------|-------------|
| "Concrete workout" | "Saved routine" or just "Workout" |
| "Slot template" | "Flexible template" or "Template" |
| "Slot template . N slot(s)" | "Template . N exercises" |
| "New concrete workout" | "New workout" |
| "New slot template" | "New flexible template" |
| History filter "Concrete" | "Routines" |
| History filter "Slot" | "Templates" |
| "Add concrete workout" | "Add workout" |
| "Add slot template" | "Add template" |

3. Update the `HistorySessionOriginFilter` short labels and footer explanations to match.

**Files to change**: `HomeView.swift`, `HistoryView.swift`, `PlanCalendarView.swift`, `SlotTemplatePlanView.swift`, `CurrentWorkoutPullUpSheet.swift`.

---

### 8. Replace the single-page AI Split Builder form with a stepped wizard

**Problem**

`AISplitBuilderView` has 5 pickers, a stepper, a weekday grid, 2 text fields, a toggle, and a generate button all in one scrollable form. There is no inline validation and the generate button may be below the fold.

**How to implement**

1. Define wizard steps:

```swift
private enum WizardStep: Int, CaseIterable {
    case goals       // Primary goal, equipment, experience, split style
    case schedule    // Sessions per week, preferred weekdays, definition preference
    case details     // Limitations, additional notes, training program toggle
}
```

2. Use a `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` and a custom step indicator:

```swift
@State private var currentStep: WizardStep = .goals

var body: some View {
    NavigationStack {
        VStack(spacing: 0) {
            stepIndicator
            TabView(selection: $currentStep) {
                goalsPage.tag(WizardStep.goals)
                schedulePage.tag(WizardStep.schedule)
                detailsPage.tag(WizardStep.details)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            navigationButtons
        }
    }
}
```

3. Add validation per step. On the schedule page, show an inline warning when `sessionsPerWeek > selectedWeekdays.count` and weekdays are not empty:

```swift
if !selectedWeekdays.isEmpty && sessionsPerWeek > selectedWeekdays.count {
    Label(
        "You selected \(sessionsPerWeek) sessions but only \(selectedWeekdays.count) training days",
        systemImage: "exclamationmark.triangle"
    )
    .font(.caption)
    .foregroundStyle(.orange)
}
```

4. Move the "Generate" action to a toolbar button or a floating button that is always visible on the last step.

**Files to change**: `AISplitBuilderView.swift`.

---

### 9. Make the AI proposal preview editable before applying

**Problem**

After the AI generates a split, the user sees a read-only preview. The only option for changes is "Regenerate" which makes another API call. There is no way to tweak individual exercises or day names.

**How to implement**

1. Convert the proposal into mutable `@State` when entering preview:

```swift
@State private var editableWorkouts: [EditableProposalDay] = []

struct EditableProposalDay: Identifiable {
    let id = UUID()
    var name: String
    var focus: String
    var exercises: [EditableProposalExercise]  // for concrete days
    var slots: [EditableProposalSlot]          // for slot days
}
```

2. Replace the `ForEach` in `previewContent` with editable rows:
   - Day names become `TextField`s.
   - Exercise rows get swipe-to-delete and a "Replace" button that opens the exercise picker.
   - Slot rows get inline editable muscle targets and suggested exercise.
   - Add a "+" button at the bottom of each day to add an exercise or slot.

3. Add drag-to-reorder on the day sections using `.onMove`.

4. When the user taps "Apply", build the final `WorkoutSplitProposal` from the edited state rather than the original AI response.

5. Add an "Undo all edits" option that resets to the original proposal.

**Files to change**: `AISplitBuilderView.swift` (preview section).

---

### 10. Improve week-at-a-glance visibility and accessibility

**Problem**

The week strip uses `Capsule` shapes that are 8x4 points (10x5 for today) with `Color.secondary.opacity(0.2)` for non-workout days. These are likely invisible on older screens and fail WCAG contrast guidelines.

**How to implement**

1. Increase the minimum touch/visual target to 24x24 points:

```swift
private func weekStripDayColumn(weekday: Int, date: Date, hasWorkout: Bool, calendar: Calendar) -> some View {
    let isToday = calendar.isDateInToday(date)
    return VStack(spacing: 4) {
        Text(shortWeekdayLabel(weekday, calendar: calendar))
            .font(.caption2.weight(isToday ? .bold : .regular))
            .foregroundStyle(isToday ? .primary : .secondary)

        ZStack {
            Circle()
                .fill(isToday ? Color.accentColor.opacity(0.15) : Color.clear)
                .frame(width: 28, height: 28)
            if hasWorkout {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
        }
    }
}
```

2. Add explicit accessibility traits:

```swift
.accessibilityAddTraits(hasWorkout ? .isSelected : [])
.accessibilityValue(hasWorkout ? "completed" : "not completed")
```

3. Ensure the empty-day indicator has at least a 3:1 contrast ratio against the background. Use `Color.secondary.opacity(0.4)` as a minimum for the stroke.

**Files to change**: `HomeView.swift` (week strip section).

---

### 11. Make unresolved slot placeholders visually obvious and actionable

**Problem**

When a user starts a workout from a slot template, unresolved slots appear as "Choose exercise" in the pull-up sheet list. The only way to resolve them is tapping the row (which normally expands/collapses). There is no visual differentiation in the collapsed state.

**How to implement**

1. Add a distinct row style for unresolved slots in `CurrentWorkoutPullUpSheet`:

```swift
if log.workoutExercise.isSlotPlaceholder {
    HStack {
        Image(systemName: "square.dashed")
            .foregroundStyle(.orange)
        VStack(alignment: .leading, spacing: 2) {
            Text(log.workoutExercise.slotLabel.isEmpty ? "Choose exercise" : log.workoutExercise.slotLabel)
                .font(.headline)
            Text("Tap to pick an exercise")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .foregroundStyle(.orange)
    }
    .padding(.vertical, 4)
    .listRowBackground(Color.orange.opacity(0.08))
}
```

2. Add a top-of-sheet banner when unresolved slots exist:

```swift
let unresolvedCount = session.exerciseLogs.filter { $0.workoutExercise.isSlotPlaceholder }.count
if unresolvedCount > 0 {
    HStack {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(.orange)
        Text("\(unresolvedCount) slot\(unresolvedCount == 1 ? "" : "s") need\(unresolvedCount == 1 ? "s" : "") an exercise")
            .font(.subheadline.weight(.medium))
        Spacer()
        Button("Resolve") {
            if let first = session.exerciseLogs.first(where: { $0.workoutExercise.isSlotPlaceholder }) {
                resolveSlotSelection = ResolveSlotWE(workoutExerciseId: first.workoutExercise.id)
            }
        }
        .buttonStyle(.bordered)
        .tint(.orange)
    }
    .padding()
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
}
```

3. Consider auto-presenting the exercise picker for the first unresolved slot when the pull-up sheet first appears via an `.onAppear` check.

**Files to change**: `CurrentWorkoutPullUpSheet.swift`.

---

### 12. Automate superset rest logic instead of manual toggling

**Problem**

`LogSetView` requires the user to manually toggle "Rest after this set" during supersets, with instructional text explaining round structure. This is error-prone and adds cognitive load on every set.

**How to implement**

1. Track superset round position in the session. Add a computed property that determines where the current exercise sits in the active superset:

```swift
struct SupersetPosition {
    let exerciseIndex: Int
    let totalInRound: Int
    let isLastInRound: Bool
}

func supersetPosition(for exerciseId: UUID, in session: WorkoutSession) -> SupersetPosition? {
    let active = session.activeExerciseIds
    guard active.count > 1, let idx = active.firstIndex(of: exerciseId) else { return nil }
    return SupersetPosition(
        exerciseIndex: idx,
        totalInRound: active.count,
        isLastInRound: idx == active.count - 1
    )
}
```

2. In `LogSetView`, auto-determine rest behavior based on position:

```swift
private var autoRestAfterSet: Bool {
    guard let pos = supersetPosition(for: exerciseId, in: session) else { return true }
    return pos.isLastInRound
}
```

3. Replace the toggle with an informational display:

```swift
if let pos = supersetPosition {
    HStack {
        Text("Superset \(pos.exerciseIndex + 1) of \(pos.totalInRound)")
            .font(.caption.weight(.medium))
        Spacer()
        if pos.isLastInRound {
            Label("Rest starts after this set", systemImage: "timer")
                .font(.caption)
                .foregroundStyle(.blue)
        } else {
            Label("No rest — next exercise in round", systemImage: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

4. Keep an advanced override: let the user long-press the rest indicator to manually toggle if they want to deviate from the auto behavior.

5. Set `restTime` automatically: 0 for non-last exercises, the exercise default for the last one.

**Files to change**: `LogSetView.swift`, `CurrentWorkoutSessionViewModel.swift` (add superset position helper).

---

## Architecture

### 13. Break up DataManager into focused services

**Problem**

`DataManager` is 800+ lines handling workout CRUD, template CRUD, session management, exercise library, training program state, display name resolution, analytics queries, and AI proposal application.

**How to implement**

1. Define protocol-based services:

```swift
protocol WorkoutRepository {
    var workouts: [Workout] { get }
    var templates: [WorkoutTemplate] { get }
    func createWorkout(name: String) -> UUID
    func createSlotTemplate(name: String, slots: [TemplateSlot]) -> UUID
    func deleteWorkout(_ workout: Workout)
    func deleteSlotTemplate(_ template: WorkoutTemplate)
    // ...
}

protocol SessionRepository {
    var completedSessions: [WorkoutSession] { get }
    func save(_ session: WorkoutSession)
    func sessionsInRange(from: Date, to: Date) -> [WorkoutSession]
    func hasCompletedSession(on date: Date) -> Bool
}

protocol TrainingProgramService {
    var program: TrainingProgramState { get set }
    func applySchedule(entries: [WorkoutPlanRef], sessionsPerWeek: Int, weekdays: [Int], anchor: Date)
}

protocol AnalyticsService {
    func weekAtAGlance(referenceDate: Date) -> WeekAtAGlance
    func completedSessionCount(inWeekContaining: Date) -> Int
}
```

2. Implement each protocol in its own file (`WorkoutStore.swift`, `SessionStore.swift`, etc.).

3. Keep a thin `AppState` (or rename `DataManager`) that composes these services and conforms to `ObservableObject` for SwiftUI injection:

```swift
final class AppState: ObservableObject {
    let workouts: WorkoutRepository
    let sessions: SessionRepository
    let program: TrainingProgramService
    let analytics: AnalyticsService
    // ...
}
```

4. Update `@EnvironmentObject` injection sites to use the specific service they need, or keep using `AppState` as the single injection point while internally delegating.

**Files to change**: `DataManager.swift` (split into 4–5 files), all views that use `@EnvironmentObject var dataVM: DataManager`.

---

### 14. Cache expensive computed properties instead of recomputing per render

**Problem**

`HomeView` computes `todayPlan`, `weekAtAGlance`, and `isPlannedWorkoutCompletedToday` as computed properties that run on every view evaluation. `weekAtAGlance` calls `hasCompletedSessionEnding` 7 times, each scanning all sessions.

**How to implement**

1. Move the computed values into `@State` and update them reactively:

```swift
@State private var cachedTodayPlan: ResolvedScheduleDay = .unscheduled
@State private var cachedWeekGlance: DataManager.WeekAtAGlance?
@State private var cachedTodayCompleted = false

var body: some View {
    // ... use cached values ...
    .task(id: refreshKey) {
        cachedTodayPlan = scheduleEngine.resolve(date: Date(), program: dataVM.trainingProgram)
        cachedWeekGlance = dataVM.weekAtAGlance(referenceDate: Date())
        if case .workout(let ref) = cachedTodayPlan {
            cachedTodayCompleted = computeIsCompleted(ref)
        }
    }
}

private var refreshKey: String {
    "\(calendarDayRefresh)-\(dataVM.completedSessions.count)-\(dataVM.trainingProgram.cycleEntries.count)"
}
```

2. The `refreshKey` ensures recomputation only when the relevant data actually changes, not on every unrelated `@Published` update from `DataManager`.

3. For the analytics path (after migrating to SwiftData), replace the in-memory scan with a fetch descriptor that returns only the count, letting the database do the filtering.

**Files to change**: `HomeView.swift`, `PlanCalendarView.swift`.

---

### 15. Replace the blunt calendarDayRefresh counter with a day-change detector

**Problem**

`calendarDayRefresh` increments on `significantTimeChangeNotification` and on every `.active` scene phase transition. Every view reading this value re-renders its full body even if the day has not changed (user briefly backgrounds and foregrounds the app).

**How to implement**

1. Create a lightweight observable that only fires on actual day changes:

```swift
final class CalendarDayMonitor: ObservableObject {
    @Published private(set) var currentDayKey: String

    private var cancellables = Set<AnyCancellable>()

    init(calendar: Calendar = .current) {
        currentDayKey = TrainingProgramState.dayKey(for: Date(), calendar: calendar)

        NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIScene.didActivateNotification))
            .sink { [weak self] _ in
                self?.checkForDayChange(calendar: calendar)
            }
            .store(in: &cancellables)
    }

    private func checkForDayChange(calendar: Calendar) {
        let newKey = TrainingProgramState.dayKey(for: Date(), calendar: calendar)
        if newKey != currentDayKey {
            currentDayKey = newKey
        }
    }
}
```

2. Inject it as an `@EnvironmentObject` or `@StateObject` at the app root.

3. Replace the `@Environment(\.calendarDayRefresh)` reads with `@EnvironmentObject var dayMonitor: CalendarDayMonitor` and use `dayMonitor.currentDayKey` as the dependency:

```swift
.task(id: dayMonitor.currentDayKey) {
    // recompute today's plan
}
```

4. Remove the `calendarDayRefresh` environment key, the `&+=` increments in `MainTabView`, and the `_ = calendarDayRefresh` reads in `HomeView` and `PlanCalendarView`.

**Files to change**: new `CalendarDayMonitor.swift`, `MainTabView.swift`, `HomeView.swift`, `PlanCalendarView.swift`, `Extensions.swift` (remove the environment key).
