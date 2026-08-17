# Automated real-user testing — Workout Log AI

Yes. You can run bots that **tap through the iPhone UI** like a person, screenshot what they see, and file issues or small fixes. FitLog already has the pieces; they just need to be aimed at the **simulator on a Mac**, not at Cursor Cloud Linux.

Cloud Agent VMs are Linux. They cannot boot Xcode or the iOS Simulator, so they cannot “use the app” the way a gym-goer would. **My Machines (`fitlog-mac`)** can.

## What to use for what

| Goal | Tool | What it actually does |
|------|------|------------------------|
| Recurring “walk the app, find friction” | **Cursor Automation** → **fitlog-mac** | Agent launches the Simulator, taps flows, records findings |
| Repeatable core journeys | **XCUITest** (`FitLogUITests`) | Scripted taps: launch, tabs, create workout, Coach gate |
| Compile + logic regressions | **FitLogTests** + GitHub **iOS CI** | Fast; does **not** drive the UI |
| PR code review | **Bugbot** | Reads diffs; never opens the app |
| Device / StoreKit / HealthKit / widgets | You on a **physical device** | [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) |
| Web/backend only | Cloud **Computer Use** | Fine for the Node proxy; useless for SwiftUI |

Official Cursor docs: [Automations](https://cursor.com/docs/cloud-agent/automations), [Computer Use](https://cursor.com/docs/cloud-agent/capabilities), [My Machines / Xcode](CLOUD_AGENT_XCODE.md).

## Layer 1 — Scripted user (XCUITest)

`FitLogUITests` launches the app with `-fitlog-ui-testing` so Sign in with Apple, onboarding, and notification prompts are skipped (see `FitLogUITestLaunch`).

Current coverage:

- Launch + main tab bar
- Tab smoke: Home, Plan, History, Coach, More (screenshots attached)
- Empty Home → **New workout** → **Push A** template → **Done** (workout listed on Home)
- Coach composer / Premium gate is visible
- Delete Account returns to sign-in (Guideline 5.1.1(v))

Run on a Mac (or ask `fitlog-mac`):

```bash
xcodebuild test \
  -project FitLog.xcodeproj \
  -scheme FitLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:FitLogUITests
```

Prefer XcodeBuildMCP `session_show_defaults` then `test_sim` when that MCP is available.

GitHub **iOS CI** still runs **FitLogTests only**. UI tests stay on the Mac worker (or a future dedicated `macos` job) because they are slower and more environment-sensitive.

## Layer 2 — Exploratory bot (Cursor + Simulator)

This is the “use it like a real user and hunt for issues” loop.

### One-time setup

1. Keep **fitlog-mac** online ([CLOUD_AGENT_XCODE.md](CLOUD_AGENT_XCODE.md) §A).
2. Open [cursor.com/automations/new](https://cursor.com/automations/new).
3. Trigger: scheduled (daily) **or** leave unscheduled and invoke from Slack.
4. Attach repo **cianfrocco4/FitLog**.
5. Paste the prompt in [automation-prompts/exploratory-user-testing.md](automation-prompts/exploratory-user-testing.md).
6. Tools: Computer Use (default), Slack `#workoutlogai-agents`.
7. Target worker: **fitlog-mac** when the UI lets you; otherwise invoke with `worker=fitlog-mac`.

Personal **Pro+** scheduled Automations often land on **Cloud Linux**. If that happens, the agent must **not** pretend it used the Simulator. It should Slack the Mac follow-up command from the prompt (same two-step pattern as the [nightly improvement loop](automation-prompts/nightly-improvement-loop.md)).

### Ad-hoc from Slack

```text
@Cursor worker=fitlog-mac repo=cianfrocco4/FitLog Follow docs/automation-prompts/exploratory-user-testing.md on main. Use the Simulator like a new free user. Screenshot issues. Implement at most 1–2 low-risk UX fixes if obvious; otherwise report only. Open a DRAFT PR only if FitLogTests pass after any code change.
```

### What the bot should walk

Mirror a first-week gym user (free tier):

1. Home — empty state, Start workout FAB, readiness card
2. Create a template workout (Push A) and start it
3. Log a set (weight + reps), rest timer chrome, finish → History
4. Plan calendar, History Overview/Sessions, Coach paywall, More → Subscription / Legal
5. Dynamic Type / dark mode if Computer Use can toggle Settings

Do **not** purchase, restore, or hit production AI unless a sandbox secret is present.

## Layer 3 — Human device QA

Automations will not catch StoreKit paywall rendering, HealthKit permission copy, widgets, Live Activities, or TestFlight. Keep [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) as the pre-submit gate.

## Accessibility identifiers (for bots and XCUITest)

Stable IDs (also spoken labels where noted):

| ID | Control |
|----|---------|
| `fitlog.startWorkout` | Home FAB “Start workout” |
| `fitlog.newWorkout` | Empty Home / start-sheet “New workout” |
| `fitlog.fromTemplate` | Empty Home “From template” |
| `fitlog.createWorkout` | New-workout sheet **Create** |
| `fitlog.quickStart.pushA` | Quick-start template **Push A** |

Prefer these IDs in new UI tests. Keep `.accessibilityLabel` / `.accessibilityHint` for VoiceOver.

## Findings → product work

- **Nightly code loop** ([nightly-improvement-loop.md](automation-prompts/nightly-improvement-loop.md)) reads the repo and implements 1–3 fixes without opening the app.
- **This exploratory loop** should prefer evidence from Simulator screenshots and XCUITest failures over static review.
- File Slack notes even when nothing is shipped. Empty “looked fine” runs are useful.

## Limits

- Cloud Linux Computer Use can drive a **browser**, not an iPhone.
- Simulator ≠ device (Health, widgets, push, StoreKit presentation).
- UI tests share one simulator; do not parallelize `FitLogUITests`.
- Do not change SwiftData schema from an exploratory run unless migration is required and tested.
