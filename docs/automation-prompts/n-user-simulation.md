# N-user exploratory simulation — prompt (Mac worker)

Paste into Slack / Agents UI with **fitlog-mac**. Simulates **N distinct gym-goers** (catalog personas), not N clones of an empty install.

```text
You are working in the FitLog iOS repo (Workout Log AI).

## Goal
Simulate N actual users. Each user is a FitLogSimulatedUserPersona with different data and a different workflow. Do not run the same empty-Home path N times.

## Environment check (required first)
Run: uname -s && which xcodebuild && xcodebuild -version

If xcodebuild is MISSING: do not open a PR. Slack #workoutlogai-agents this follow-up:

  @Cursor worker=fitlog-mac repo=cianfrocco4/FitLog Follow docs/automation-prompts/n-user-simulation.md with N=5. Run scripts/run-simulated-users.sh 5, then Computer-Use the Simulator as each failing or interesting persona. Screenshot issues. Implement at most 1–2 low-risk UX fixes if obvious. DRAFT PR only if FitLogTests pass after code changes.

Then stop.

## Catalog (N users, in order)
1. newFree — empty Home, create Push A, Coach Premium gate
2. returningFree — library + history; Start sheet Recent; History 30-day range is locked
3. premiumLifter — history + Active subscription; 90-day range unlocked
4. cardioHobbyist — Zone 2 cardio workout on Home
5. planFollower — today assigned Push A on Plan

N defaults to 5. If the user asked for a smaller N, use the first N personas. If they asked for more than 5, run the catalog once, then REPEAT extra passes (scripts/run-simulated-users.sh; REPEAT=2) rather than inventing fake users.

## What to run
1) Prefer XcodeBuildMCP session_show_defaults.
2) scripts/run-simulated-users.sh N
   (or xcodebuild test -only-testing:FitLogUITests/FitLogSimulatedUserUITests)
3) If a persona test fails: launch that persona in the Simulator with:
     -fitlog-ui-testing -fitlog-ui-reset-store -fitlog-ui-persona <rawValue>
   Use Computer Use to finish the workflow like that person and screenshot the failure.
4) Optionally walk one extra messy path per failed persona (log a set, rotate Dynamic Type) — still no real purchases.

## After
Findings list ranked by user impact. At most 1–2 low-risk fixes. FitLogTests required before a DRAFT PR. Slack summary with N, pass/fail per persona, and screenshots.
```

See [AUTOMATED_USER_TESTING.md](../AUTOMATED_USER_TESTING.md).
