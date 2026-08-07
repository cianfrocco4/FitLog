# FitLog Mac verify + open PR — prompt

Use this when invoking `@Cursor worker=fitlog-mac` (Slack or Agents UI) after the nightly loop pushed a branch.

```text
You are on the FitLog Mac worker (fitlog-mac) for repo cianfrocco4/FitLog.

Task: verify an existing feature branch, then open a DRAFT PR only if green.

1) Identify the branch from the user message. git fetch && git checkout BRANCH && git pull.
2) Confirm: which xcodebuild && xcodebuild -version
3) Build: xcodebuild build -project FitLog.xcodeproj -scheme FitLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -skipMacroValidation
   Prefer XcodeBuildMCP session_show_defaults + build_sim when available.
4) Test: xcodebuild test -project FitLog.xcodeproj -scheme FitLog -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitLogTests
   Prefer XcodeBuildMCP test_sim when available.
5) If build or tests fail: fix straightforward failures if safe; re-run. If still failing, do NOT open a PR. Report the failures in Slack #workoutlogai-agents.
6) If both pass: open a DRAFT PR to main with summary, test plan, exact commands run, and pass evidence. Never merge.
7) Slack: PR link + verification status.
```
