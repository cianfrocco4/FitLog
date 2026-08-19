# Living-user qualitative review — prompt (Mac worker)

Use this **after** a living-users run (GitHub Action artifact or local `living-users/`). The app already wrote structured likes/dislikes/bugs from store state. This pass adds **what a person would notice on screen**.

```text
You are on the FitLog Mac worker (fitlog-mac) for repo cianfrocco4/FitLog.

## Goal
Read the simulated users’ written reports, look at their tab screenshots (or open their persistent stores in the Simulator), and add UI/workflow findings they could not express in JSON: clipping, confusing hierarchy, dead-end taps, missing a11y, dark-mode issues.

## Environment
uname -s && which xcodebuild && xcodebuild -version
If xcodebuild is missing, Slack #workoutlogai-agents:

  Download the latest Actions artifacts living-user-stores + living-user-screenshots from workflow "Living users", read INBOX.md, and report UI notes from screenshots only.

Then stop unless you can open the PNGs.

## Do
1) Read living-users/INBOX.md (or unzip the living-user-stores artifact). Treat recurring note ids as the users’ own likes/dislikes/bugs.
2) Open living-user-screenshots (or living-users/screenshots/<persona>/YYYY-MM-DD-*.png). For each persona, glance at Home, Plan, History, Coach, More.
3) Add at most 5 extra notes: visual bugs, copy that fights the JSON report, or workflow dead ends. Do not contradict a store-backed bug without evidence.
4) Do NOT pass -fitlog-ui-reset-store. If you launch the Simulator to click around, use:
   -fitlog-ui-testing -fitlog-ui-persistent-store -fitlog-ui-persona <id>
   (no daily-living unless you intend to log another session)
5) Slack #workoutlogai-agents with: inbox highlights + screenshot notes. Implement at most 1 low-risk UX fix if obvious; otherwise report only. Open a DRAFT PR only if FitLogTests pass after a code change.
```
