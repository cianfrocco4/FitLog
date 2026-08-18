# Exploratory user testing — prompt (Mac worker)

Paste into a Cursor Automation, or invoke from Slack / Agents UI with **fitlog-mac**.

This run must **use the iOS Simulator like a new free user**. It is not a code-review pass. The nightly improvement loop already reads the repo; this loop should produce **screenshots, XCUITest evidence, and UX notes**.

```text
You are working in the FitLog iOS repo (Workout Log AI) on branch main.

## Goal
Use the app like a real first-week free user. Find crashes, dead ends, confusing copy, missing a11y, and small UX wins. Prefer evidence from the Simulator over static code reading.

You are executing a Mac Simulator run unless you can prove xcodebuild is missing.

## Environment check (required first)
Run:
  uname -s && which xcodebuild && xcodebuild -version

### If xcodebuild is MISSING (typical Cursor Cloud Linux)
Hard rules:
- Do NOT open a pull request.
- Do NOT claim you used the iOS app or Simulator.
- Post Slack to #workoutlogai-agents with this exact follow-up (no BRANCH needed if staying on main):

  @Cursor worker=fitlog-mac repo=cianfrocco4/FitLog Follow docs/automation-prompts/exploratory-user-testing.md. Use the Simulator like a new free user. Screenshot issues. Implement at most 1–2 low-risk UX fixes if obvious; otherwise report only. Open a DRAFT PR only if FitLogTests pass after any code change.

Then stop.

### If xcodebuild IS available (My Machines / macOS)
Continue below.

## Product exploration (required)
1) Prefer XcodeBuildMCP: session_show_defaults, then build_sim / test_sim / build_run_sim for scheme FitLog, destination iPhone 17 Pro (or the session default iPhone).
2) Run FitLogUITests:
     xcodebuild test -project FitLog.xcodeproj -scheme FitLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitLogUITests
   If that destination is missing, pick an available iPhone simulator. Attach failing logs.
3) Launch the app in the Simulator (Debug, StoreKit Configuration.storekit). Launch argument -fitlog-ui-testing skips Apple login / onboarding — for a *true* first-run, also try one launch WITHOUT that flag and screenshot onboarding, then stop that install (do not fight Sign in with Apple).
4) Walk these flows as a FREE user. Screenshot each major screen. Use VoiceOver/accessibility labels and IDs in docs/AUTOMATED_USER_TESTING.md when tapping:
   - Home empty state, Start workout FAB, readiness card
   - New workout → Push A (or another quick-start) → Start workout
   - Log at least one set (weight + reps) if the log UI is reachable; rest timer chrome; Finish → completion summary → History
   - Plan tab calendar
   - History Overview / Sessions
   - Coach tab: composer visible; Send/starter should gate Premium (paywall), not silently fail
   - More: Subscription (Free), Legal & Support links exist, Delete Account visible when UI-test login bypass is on
5) Optional: toggle appearance (light/dark) and a larger Dynamic Type size if Computer Use can reach Settings; screenshot Home + log sheet.
6) Do NOT complete a real App Store purchase, Restore against production, or send paid Coach traffic unless a documented sandbox secret is in the environment.

## After exploration
Write a short findings list: bugs, UX friction, nice-to-haves. Rank by user impact.

Implement at most 1–2 highest-impact, low-risk UI/copy/a11y fixes.
- No large refactors.
- No SwiftData schema changes unless clearly required and migration-safe.
- Respect freemium/paywall.
- Follow existing accessibilityLabel / accessibilityHint / accessibilityIdentifier patterns.

If you changed code:
- MUST run Debug simulator build (scheme FitLog)
- MUST run FitLogTests
- Re-run any FitLogUITests that cover the change
- Only if build + FitLogTests pass: open a DRAFT PR to main with screenshots/findings/test plan. Never merge.
If you did not change code: no PR; Slack the findings and screenshot summary.

If build/tests fail: fix straightforward issues or stop; no PR.

## Slack
Post to #workoutlogai-agents: findings, whether a draft PR opened, Simulator used, and XCUITest pass/fail.
```

## How to invoke

**Slack / Agents UI (Mac awake, LaunchAgent running):**

```text
@Cursor worker=fitlog-mac repo=cianfrocco4/FitLog Follow docs/automation-prompts/exploratory-user-testing.md. Use the Simulator like a new free user. Screenshot issues. Implement at most 1–2 low-risk UX fixes if obvious; otherwise report only. Open a DRAFT PR only if FitLogTests pass after any code change.
```

**Scheduled Automation:** attach repo `cianfrocco4/FitLog`, paste the prompt above. On Pro+, scheduled runs often hit Cloud Linux — the prompt already Slack-handoffs to `fitlog-mac`.

See [AUTOMATED_USER_TESTING.md](../AUTOMATED_USER_TESTING.md) and [CLOUD_AGENT_XCODE.md](../CLOUD_AGENT_XCODE.md).
