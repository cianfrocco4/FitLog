# Cloud agents + Xcode (Cursor Pro+)

Managed Cursor Cloud Agent VMs are **Linux**. They cannot run real Xcode or the iOS Simulator.

On **Cursor Pro+**, use **My Machines**: a worker on your Mac so automations/cloud agents execute tool calls where Xcode already lives. Pair that with **GitHub Actions iOS CI** so PRs still get build/test when the Mac is asleep.

## A. My Machines (agent can `xcodebuild` / XcodeBuildMCP)

### 1. Install the agent CLI

```bash
curl https://cursor.com/install -fsS | bash
agent --version
```

Restart the terminal (or `source` your shell profile) if `agent` is not on `PATH`.

### 2. Sign in

```bash
agent login
```

Complete the browser login with the same Cursor account that owns the FitLog automations.

### 3. Start a FitLog worker

```bash
cd /Users/anthony/Documents/Projects/FitLog
agent worker start --name "fitlog-mac"
```

Keep this process running while you want automations to use this Mac.

Confirm at [cursor.com/agents](https://cursor.com/agents) that **fitlog-mac** appears for repo `cianfrocco4/FitLog`.

### 4. Enable self-hosted for Cloud Agents

1. Open [Cloud Agents dashboard](https://cursor.com/dashboard/cloud-agents).
2. Open **Self-Hosted**.
3. Turn on **Allow Self-Hosted Agents** (Pro+ / personal My Machines).

When the worker is online and registered for FitLog, cloud/automation runs for that repo can claim it. If a run stays on a Linux VM instead, check that the worker is still running and the git remote matches `cianfrocco4/FitLog`.

Optional Slack force: `@Cursor worker=fitlog-mac …`

### 5. Verify Xcode on the worker

In a cloud agent session on **fitlog-mac**:

```bash
xcodebuild -version
xcrun simctl list devices available | grep "iPhone 17 Pro"
```

Then build (or use XcodeBuildMCP `build_sim` after `session_show_defaults`).

Local XcodeBuildMCP (`.cursor/mcp.json`) runs as a **stdio** MCP on the worker machine, so it is available when tools execute on My Machines — not on managed Linux VMs.

### 6. Keep the worker alive (optional LaunchAgent)

A ready-made plist lives at [`scripts/macos/com.fitlog.cursor-worker.plist`](../scripts/macos/com.fitlog.cursor-worker.plist).

```bash
cp scripts/macos/com.fitlog.cursor-worker.plist ~/Library/LaunchAgents/
# Ensure `agent` is on PATH for launchd (symlink into /usr/local/bin if needed):
#   sudo ln -sf "$HOME/.local/bin/agent" /usr/local/bin/agent
launchctl load ~/Library/LaunchAgents/com.fitlog.cursor-worker.plist
tail -f /tmp/fitlog-cursor-worker.log
```

Mac sleep / lid close still pauses work — use a plugged-in Mac that stays awake, or rely on **iOS CI** when offline.

### Limits on Pro+

| Capability | Pro+ |
|------------|------|
| My Machines (personal Mac worker) for interactive / Slack `worker=` runs | Yes |
| **Scheduled Automations targeting My Machines** | Often **not** available on personal Pro+ — Automations usually run on Cursor Cloud (Linux). Team/Enterprise self-hosted is the supported path for automation→Mac. |
| Shared Self-Hosted Pool (team Mac fleet) | Enterprise (service account) |
| Managed Linux environment with real Xcode | Not available |

**Pro+ two-step workflow (recommended):**

1. **Nightly Automation** (Cloud Linux) — implement on a branch, **do not open a PR**, Slack a `worker=fitlog-mac` verify command. Prompt: [`automation-prompts/nightly-improvement-loop.md`](automation-prompts/nightly-improvement-loop.md).
2. **Mac verify** — run that Slack/`@Cursor worker=fitlog-mac` command (Mac awake, LaunchAgent running). Prompt helper: [`automation-prompts/mac-verify-and-pr.md`](automation-prompts/mac-verify-and-pr.md). Opens a **draft PR only if build + FitLogTests pass**.
3. **GitHub iOS CI** — backstop on the PR before merge.

## B. GitHub Actions iOS CI (PR merge gate)

Workflow: [`.github/workflows/ios-ci.yml`](../.github/workflows/ios-ci.yml)

- Triggers: PRs to `main`, pushes to `main`, manual dispatch
- Runner: `macos-15` + latest stable Xcode
- Actions: resolve packages → Debug simulator build → `FitLogTests` only (no UI tests)

This runs whether or not your Mac worker is online. Treat a green **iOS CI** check as the hard gate before merging automation draft PRs.

## Recommended division of labor

| Job | Where |
|-----|--------|
| Nightly / review automations implement code | My Machines (`fitlog-mac`) when online |
| Compile + unit tests before merge | GitHub Actions **iOS CI** |
| Scripted UI journeys (XCUITest) | My Machines (`fitlog-mac`); see [AUTOMATED_USER_TESTING.md](AUTOMATED_USER_TESTING.md) |
| N simulated users (personas) | `scripts/run-simulated-users.sh` on `fitlog-mac`; prompt [n-user-simulation.md](automation-prompts/n-user-simulation.md) |
| Daily living users (History grows) | GitHub Action **Living users** (cloud) or LaunchAgent / `fitlog-mac` locally |
| Exploratory “use it like a user” bot | Automation prompt [exploratory-user-testing.md](automation-prompts/exploratory-user-testing.md) on `fitlog-mac` |
| Device / StoreKit / HealthKit UX smoke | You (human) on a real device or local Simulator |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Automation can’t find Xcode | Worker not running, or run landed on Linux — restart `agent worker start --name fitlog-mac` |
| `worker=fitlog-mac` wrong repo | Start the worker from the FitLog checkout (git remote must be `cianfrocco4/FitLog`) |
| iOS CI fails on destination | Runner image missing that simulator name — workflow falls back across iPhone models |
| Signing errors in CI | Workflow sets `CODE_SIGNING_ALLOWED=NO` for simulator Debug; don’t require Release secrets for CI |
