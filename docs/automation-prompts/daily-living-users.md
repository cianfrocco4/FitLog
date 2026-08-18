# Daily living users — cloud + Mac

## Cloud (GitHub Actions)

Cursor Cloud Linux **cannot** run Xcode. Use the **Living users** GitHub Action (`macos-15` + iOS Simulator). Stores persist in Actions cache and the `living-user-stores` artifact.

After the workflow is on `main`:

```bash
gh workflow run "Living users" --ref main
```

Schedule: `.github/workflows/living-users.yml` (`cron: 0 11 * * *` UTC).

If you are in a Cursor Cloud agent, run that `gh` command. Do not try `xcodebuild` on Linux.

## Mac worker (optional)

```text
You are on the FitLog Mac worker (fitlog-mac) for repo cianfrocco4/FitLog.

## Goal
Run the daily living-user tick so simulated gym-goers build real History over calendar time.

## Environment
uname -s && which xcodebuild && xcodebuild -version
If xcodebuild is missing, Slack #workoutlogai-agents:

  Cloud path: gh workflow run "Living users" --ref main

Then stop.

## Do
1) Prefer GitHub Actions: gh workflow run "Living users" --ref main
2) Or locally: LIVING_USERS_STORE_DIR=$PWD/living-users scripts/run-daily-living-users.sh 5
3) Do NOT pass -fitlog-ui-reset-store. Slack tick outcomes from the log.
```
