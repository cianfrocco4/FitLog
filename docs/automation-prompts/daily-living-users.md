# Daily living users — prompt (Mac worker)

Scheduled **daily** on **fitlog-mac**. Each persona keeps a persistent store and logs **today’s** workout when it is a training day. History accumulates (week 2 looks like a real gym-goer; week 8 has PRs/volume).

Do **not** run `scripts/run-simulated-users.sh` or `-fitlog-ui-reset-store` — those wipe History.

```text
You are on the FitLog Mac worker (fitlog-mac) for repo cianfrocco4/FitLog.

## Goal
Run the daily living-user tick so simulated gym-goers build real History over calendar time.

## Environment
uname -s && which xcodebuild && xcodebuild -version
If xcodebuild is missing: Slack #workoutlogai-agents this follow-up, then stop:

  @Cursor worker=fitlog-mac repo=cianfrocco4/FitLog Follow docs/automation-prompts/daily-living-users.md. Run scripts/run-daily-living-users.sh 5. Do not reset stores. Slack tick outcomes.

## Do
1) git fetch && git checkout main && git pull (or stay on the living-users branch if that is what this Mac tracks).
2) scripts/run-daily-living-users.sh 5
3) Read the printed tick log (restDay / alreadyLoggedToday / logged).
4) Optional: launch one persona without daily-living and screenshot History:
     xcrun simctl launch booted com.acianfrocco.FitLog -fitlog-ui-testing -fitlog-ui-persistent-store -fitlog-ui-persona returningFree
5) Do NOT erase simulators, do NOT pass -fitlog-ui-reset-store, do NOT open a PR unless the script failed and you have a small fix.
6) Slack #workoutlogai-agents: date, per-persona outcome, session counts from the tick log.

If the Mac was asleep and this run is late, still run once — living ticks are idempotent for the same calendar day.
```

Reliable schedule on Pro+ is **launchd on the Mac** (`scripts/macos/com.fitlog.daily-living-users.plist`), because Cursor scheduled Automations often land on Cloud Linux. See [AUTOMATED_USER_TESTING.md](../AUTOMATED_USER_TESTING.md).
