# FitLog Nightly Improvement Loop — prompt (Pro+ two-step)

Paste this into the **FitLog Nightly Improvement Loop** automation instructions (replace the old prompt).

This is the **Pro+** workflow: nightly work runs on Cursor Cloud (no Xcode). It must **not** open a PR until a Mac worker has verified build + tests.

```text
You are working in the FitLog iOS repo (Workout Log AI) on branch main.

## Goal (Pro+ two-step)
Step 1 (this run): analyze, implement 1–3 low-risk improvements on a feature branch, push the branch, and ask Slack for Mac verification.
Step 2 (separate Mac run): someone (or you, if invoked with worker=fitlog-mac) builds/tests on the Mac and only then opens a DRAFT PR.

You are executing STEP 1 unless you can prove xcodebuild works in THIS environment.

## Environment check (required first)
Run:
  uname -s && which xcodebuild && xcodebuild -version

### If xcodebuild is MISSING (typical Cursor Cloud Linux)
Hard rules:
- Do NOT open a pull request.
- Do NOT claim iOS build/tests passed.
- You MAY create/push a branch with code changes.
- After pushing, post Slack to #workoutlogai-agents with:
  1) Short summary of findings + changes
  2) Branch name
  3) This exact follow-up command for a Mac worker (fill in BRANCH):

  @Cursor worker=fitlog-mac repo=cianfrocco4/FitLog On branch BRANCH: pull latest, run Debug simulator build for scheme FitLog, run FitLogTests only, fix any failures you can, and ONLY if build+tests pass open a DRAFT PR to main with summary/test plan. If build or tests fail, do not open a PR; report failures in Slack instead.

### If xcodebuild IS available (My Machines / macOS)
You may complete Step 1 + Step 2 in one run:
1) Implement changes on a branch
2) MUST run simulator Debug build (scheme FitLog)
3) MUST run: xcodebuild test -project FitLog.xcodeproj -scheme FitLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitLogTests
   (or XcodeBuildMCP build_sim / test_sim after session_show_defaults)
4) Only if both succeed: open a DRAFT PR to main (never merge) with commands + results
5) Slack summary with PR link
If build/tests fail: fix or stop; no PR.

## Product work (Step 1)
1) Review recent code and product gaps. Prefer real user workflows: start workout → log sets → finish → history; readiness; freemium gates; paywall; widgets.
   Also read simulated-user feedback before inventing work:
   - GitHub issue titled **Living user feedback inbox** (latest comment), or
   - `gh run list --workflow "Living users" --limit 1` then download artifact `living-user-stores` and read `INBOX.md`
   Prefer recurring note ids (dislikes/bugs/improvements) that showed up more than once.
2) Short findings list (bugs, UX friction, small features). Cite inbox ids when you use them.
3) Implement at most 1–3 highest-impact, low-risk items. No large refactors. No SwiftData schema changes unless clearly required and migration-safe. Respect freemium/paywall.
4) Follow the environment rules above for branch push vs PR.

If nothing is safely actionable: no branch/PR; explain in Slack.
```

## Step 2 — how verification happens on Pro+

After the nightly Slack message appears, run the suggested command in Slack (or Agents UI with **fitlog-mac** selected):

```text
@Cursor worker=fitlog-mac repo=cianfrocco4/FitLog On branch <BRANCH>: pull latest, run Debug simulator build for scheme FitLog, run FitLogTests only, fix any failures you can, and ONLY if build+tests pass open a DRAFT PR to main with summary/test plan. If build or tests fail, do not open a PR; report failures in Slack instead.
```

Requirements:
- LaunchAgent worker `fitlog-mac` is running
- Mac is awake

GitHub **iOS CI** remains the merge backstop after the draft PR opens.
