# FitLog Nightly Improvement Loop — prompt (hardened)

Paste this into the **FitLog Nightly Improvement Loop** automation instructions (replace the old prompt).

```text
You are working in the FitLog iOS repo (Workout Log AI) on branch main.

Goal: improve the product, verify with a real iOS build/test when possible, then leave a draft PR for human review.

## Hard verification gates (do not skip)

1. At the start, run:
   `uname -s && which xcodebuild && xcodebuild -version`
2. If `xcodebuild` is missing (typical on Linux Cursor Cloud VMs):
   - You MAY still analyze the codebase and propose changes.
   - You MUST NOT claim you built or tested on iOS.
   - Prefer opening a DRAFT PR only if changes are tiny and clearly correct, and the PR body must start with:
     `⚠️ UNVERIFIED ON iOS — no xcodebuild in this environment. Waiting on GitHub Actions "iOS CI".`
   - In Slack, say explicitly that build/test did not run locally and human/CI must verify.
3. If `xcodebuild` IS available (My Machines / macOS worker):
   - After code changes, you MUST run a simulator Debug build for scheme FitLog.
   - Then run unit tests: `xcodebuild test -project FitLog.xcodeproj -scheme FitLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitLogTests` (or the booted iPhone 17 Pro id if available).
   - Prefer XcodeBuildMCP `session_show_defaults` then `build_sim` / `test_sim` when those tools are available.
   - If build or tests fail: fix or revert; do NOT open a PR with known red build/tests.
   - Only open a DRAFT PR after build + FitLogTests succeed. Include the exact commands and pass/fail in the PR body.

## Product work

1. Review recent code and product gaps. Prefer real user workflows: start workout → log sets → finish → history; readiness; freemium gates; paywall; widgets. Also consider Slack #workoutlogai-agents triage notes and App Store review backlog.
2. Write a short findings list (bugs, UX friction, small features).
3. Implement at most 1–3 highest-impact, low-risk items. No large refactors. No SwiftData schema changes unless clearly required and migration-safe. Respect freemium/paywall behavior.
4. Open a DRAFT pull request to main (never merge) with summary, test plan, residual risks, and verification evidence from the gates above.
5. Post a short Slack update with the PR link, what changed, and whether iOS build/tests actually ran.

If nothing is safely actionable, open no PR and explain why in Slack.
```

## Why this is needed

On Cursor **Pro+**, scheduled Automations usually run on **managed Linux cloud VMs**, which do **not** have Xcode. Your `fitlog-mac` My Machines worker is great for interactive agents, but Automations often cannot select it on personal plans.

So the nightly loop can edit code and open a PR without ever compiling. GitHub Actions **iOS CI** is the reliable compile/test gate for those PRs until Automations can target My Machines (Team/Enterprise self-hosted) or Cursor adds that for Pro+.
