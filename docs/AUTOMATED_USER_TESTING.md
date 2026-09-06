# Automated real-user testing — Workout Log AI

Yes. You can run bots that **tap through the iPhone UI** like a person, screenshot what they see, and file issues or small fixes. FitLog already has the pieces; they just need to be aimed at the **simulator on a Mac**, not at Cursor Cloud Linux.

Cloud Agent VMs are Linux. They cannot boot Xcode or the iOS Simulator, so they cannot “use the app” the way a gym-goer would. **My Machines (`fitlog-mac`)** can.

## What to use for what

| Goal | Tool | What it actually does |
|------|------|------------------------|
| Recurring “walk the app, find friction” | **Cursor Automation** → **fitlog-mac** | Agent launches the Simulator, taps flows, records findings |
| Repeatable core journeys | **XCUITest** (`FitLogUITests`) | Scripted taps: launch, tabs, create workout, Coach gate |
| **N distinct users** | **Personas + seeder + `FitLogSimulatedUserUITests`** | Each run is a different gym-goer (data + workflow), not N clones |
| **Likes / dislikes / bugs / UX notes** | **Living-user reviews** + GitHub inbox issue | Each persona reports from their store; tabs are screenshotted |
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

## Layer 1b — N simulated users (personas)

Yes: you can simulate **N actual users** if each one is a **persona** (different history, Premium vs free, cardio vs strength, plan vs scratch). Running the empty-app path N times is not N users.

Catalog (`FitLogSimulatedUserPersona`, N=5):

| Persona | Premium | Starting data | Workflow under test |
|---------|---------|---------------|---------------------|
| `newFree` | No | Empty library | Create Push A; Coach gate |
| `returningFree` | No | Push/Pull/Legs + recent and 40-day-old sessions | Start sheet Recent; History 30-day range locked |
| `premiumLifter` | Yes | Same library, deeper history | 90-day history unlocked; Subscription Active |
| `cardioHobbyist` | No | Zone 2 cardio workout + sessions | Home shows Zone 2 |
| `planFollower` | No | Push A assigned to today | Plan calendar shows today’s workout |

Launch one user in the Simulator:

```text
-fitlog-ui-testing -fitlog-ui-reset-store -fitlog-ui-persona returningFree
```

Run the first N catalog users on a Mac:

```bash
scripts/run-simulated-users.sh 5
# first 3 users:
scripts/run-simulated-users.sh 3
# soak beyond 5 (repeats the catalog; does not invent new people):
REPEAT=2 scripts/run-simulated-users.sh 5
```

Each XCUITest launch **resets** SwiftData then seeds that persona, so users do not leak into each other. They still run **one at a time** on one Simulator (the UI test target is not parallel). True concurrent N would mean N Simulator clones on a beefy Mac; that is optional and more flaky.

Cursor / Slack (Mac awake):

```text
@Cursor worker=fitlog-mac repo=cianfrocco4/FitLog Follow docs/automation-prompts/n-user-simulation.md with N=5.
```

Seeder logic is covered by `FitLogTests/SimulatedUserSeederTests` (runs in GitHub iOS CI). The tap journeys themselves stay on `fitlog-mac`.

## Layer 1c — Daily living users (history that grows)

One-shot snapshot tests **reset** the store. To build History the way real people do, run a **daily tick** that:

1. Uses a **persistent** SwiftData file per persona (`FitLogData-sim-returningFree.store`, …) so five users share one Simulator without overwriting each other
2. **Never erases** yesterday’s sessions
3. On a **training day**, logs one workout (idempotent if you run twice the same day)
4. On a **rest day**, opens the app and leaves History unchanged

Weekly cadence (Gregorian weekday: Sun=1):

| Persona | Trains |
|---------|--------|
| `newFree` | Tue, Thu |
| `returningFree` | Mon, Wed, Fri |
| `premiumLifter` | Mon, Tue, Thu, Fri |
| `cardioHobbyist` | Tue, Thu, Sat |
| `planFollower` | Mon, Wed, Fri |

**Cloud (GitHub Actions, recommended if you want this without a Mac awake):**

Cursor Cloud Agent VMs are **Linux** and cannot boot the iOS Simulator. GitHub-hosted **macos-15** runners can. Workflow: [`.github/workflows/living-users.yml`](../.github/workflows/living-users.yml).

1. Merge this to `main` (scheduled workflows only run on the default branch).
2. Repo **Settings → Actions → General**: allow Actions, and allow the `Living users` workflow.
3. It runs daily at **11:00 UTC** (~07:00 Eastern in summer). Each run restores cached `living-users/` SwiftData files, ticks all five personas, writes reviews, screenshots the main tabs, then saves the cache + artifacts.
4. Run now (after merge): GitHub **Actions → Living users → Run workflow**, or:

```bash
gh workflow run "Living users" --ref main
```

From a Cursor Cloud session you can trigger the same command (`gh` is authenticated); the work still happens on GitHub’s Mac, not on the Linux agent VM.

Download History: Actions run → artifact **living-user-stores**. Tab screenshots: **living-user-screenshots**. Human-readable digest: `INBOX.md` inside the stores artifact, also posted to the **Living user feedback inbox** issue.

**Local Mac LaunchAgent** (optional if the GitHub workflow is on):

```bash
chmod +x scripts/run-daily-living-users.sh
# Edit the cd path in the plist if your checkout is not /Users/anthony/Documents/Projects/FitLog
cp scripts/macos/com.fitlog.daily-living-users.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.fitlog.daily-living-users.plist
# Default: 07:00 local. Logs: /tmp/fitlog-daily-living.log
```

Run once by hand on a Mac:

```bash
scripts/run-daily-living-users.sh 5
# Cloud-style persistence on a Mac:
LIVING_USERS_STORE_DIR="$PWD/living-users" scripts/run-daily-living-users.sh 5
```

Inspect ticks (after a run):

```bash
DATA=$(xcrun simctl get_app_container booted com.acianfrocco.FitLog data)
tail "$DATA/Documents/fitlog-living-ticks.jsonl"
tail "$DATA/Documents/fitlog-living-reviews.jsonl"
```

Browse a grown user (no extra log unless you also pass daily-living):

```bash
xcrun simctl launch booted com.acianfrocco.FitLog \
  -fitlog-ui-testing -fitlog-ui-persistent-store -fitlog-ui-persona returningFree
```

**Cursor Automation:** cannot run the Simulator on Cloud Linux. Use the **Living users** GitHub Action for cloud History, or Slack-handoff to `fitlog-mac` ([daily-living-users.md](automation-prompts/daily-living-users.md)).

Do **not** erase that Simulator or pass `-fitlog-ui-reset-store` on living stores. Snapshot XCUITests use the default `FitLogData.store` and leave `FitLogData-sim-*` alone.

## Layer 1d — Users report likes, dislikes, bugs, and improvements

Living users do more than log workouts. After each daily tick they **write a structured review** from the actual store (session count, History age, Plan assignment, Premium vs Coach, empty library, and so on). That is how they tell you what they like, what they don’t, what looks broken, and what would make the workflow better.

Each review is first-person notes with stable ids (`dislike.history.14_day_cap`, `bug.plan.missing_today`, …) so the same complaint can stack across days.

**What gets written (Simulator Documents, then copied to `living-users/`):**

| File | Role |
|------|------|
| `fitlog-living-reviews.jsonl` | One JSON object per persona per day |
| `fitlog-living-review-<persona>.md` | Latest markdown for that user |
| `INBOX.md` | Digest: recurring ids + latest day’s full reports |
| Tab screenshots | Home / Plan / History / Coach / More (artifact, not cached) |

Launch flags (already passed by `scripts/run-daily-living-users.sh`):

```text
-fitlog-ui-testing -fitlog-ui-persistent-store -fitlog-ui-daily-living
-fitlog-ui-write-review -fitlog-ui-persona returningFree
```

Tab screenshots use UI-test-only deep links (`fitlog://uitest/tab/history`, …). Production ignores those URLs.

**Where to read the reports**

1. GitHub **Actions → Living users** → artifacts `living-user-stores` (`INBOX.md`) and `living-user-screenshots`.
2. Standing issue **Living user feedback inbox** (the workflow creates it on first success and comments each run).
3. Locally: `LIVING_USERS_STORE_DIR=$PWD/living-users scripts/run-daily-living-users.sh 5` then open `living-users/INBOX.md`. Optional: `POST_LIVING_USER_REVIEWS=1` if `gh` can open issues.

Heuristic reviews are grounded in store state (for example a free user with sessions older than 14 days dislikes the History cap). They will not catch every visual bug. For a qualitative pass on the screenshots, run [automation-prompts/living-user-review.md](automation-prompts/living-user-review.md) on `fitlog-mac`.

Reviewer logic is covered by `FitLogTests/SimulatedUserReviewerTests` (GitHub iOS CI).

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
| `fitlog.homeWeekStrip.lastSession` | Home week strip last-session recap |
| `fitlog.homeWeekStrip.startThisWorkout` | Home week strip **Start this workout** |
| `fitlog.programGallery.lastSession` | Program template gallery last-session recap |
| `fitlog.programGallery.startThisWorkout` | Program template gallery **Start this workout** |
| `fitlog.subscriptionSettings.lastSession` | More → Subscription last-session recap |
| `fitlog.subscriptionSettings.startThisWorkout` | More → Subscription **Start this workout** |

Prefer these IDs in new UI tests. Keep `.accessibilityLabel` / `.accessibilityHint` for VoiceOver.

## Findings → product work

- **Living-user inbox** (Layer 1d) is the default source for “what users like / don’t like / bugs / workflow.” Prefer recurring note ids and screenshot artifacts over guesswork.
- **Nightly code loop** ([nightly-improvement-loop.md](automation-prompts/nightly-improvement-loop.md)) should read that inbox (GitHub issue or latest artifact) and implement 1–3 fixes without requiring the Simulator.
- **This exploratory loop** should prefer evidence from Simulator screenshots and XCUITest failures over static review.
- File Slack notes even when nothing is shipped. Empty “looked fine” runs are useful.

## Limits

- Cloud Linux Computer Use can drive a **browser**, not an iPhone.
- Simulator ≠ device (Health, widgets, push, StoreKit presentation).
- UI tests share one simulator; `FitLogUITests` is not parallelized. Simulate N users **sequentially** via personas (`scripts/run-simulated-users.sh`).
- Do not change SwiftData schema from an exploratory run unless migration is required and tested.
