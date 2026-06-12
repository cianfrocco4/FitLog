# App Store Connect — Copy-Paste Setup

Use this when creating the app record in [App Store Connect](https://appstoreconnect.apple.com).

## App record

| Field | Value |
|-------|--------|
| Platform | iOS |
| Name | The Workout Log |
| Primary Language | English (U.S.) |
| Bundle ID | `com.acianfrocco.FitLog` |
| SKU | `fitlog-ios-1` |

## URLs (after GitHub Pages deploy)

| Field | URL |
|-------|-----|
| Privacy Policy | `https://cianfrocco4.github.io/FitLog/privacy-policy.html` |
| Support | `https://cianfrocco4.github.io/FitLog/support.html` |
| Marketing | Optional — same support URL or GitHub repo |

Replace `cianfrocco4` with your GitHub username if different.

## Metadata (from APP_STORE_METADATA.md)

**Subtitle:** Log lifts. Rest. Repeat.

**Keywords:** gym,fitness,strength,lifting,logger,exercise,reps,timer,training,weightlifting,powerlifting,sets

**Category:** Health & Fitness

**What's New (v1.0):**
```
Welcome to The Workout Log.

• Plan workouts with 60+ exercises or your own
• Log sets (lbs), rest timer with notifications
• Weekly summary and full workout history
• Sign in with Apple; data stays on your device
```

Full description: see [APP_STORE_METADATA.md](../APP_STORE_METADATA.md).

## Build assignment

- Version: **1.0**
- Build: **1** (increment for each re-upload)
- Archive location: `build/FitLog.xcarchive` (local, gitignored)

## Checklist

- [ ] App record created
- [ ] Privacy & support URLs live and entered
- [ ] Screenshots uploaded (6.7", 6.1", iPad 13") — baseline in `AppStoreScreenshots/` after running script
- [ ] Privacy labels completed — see [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)
- [ ] Age rating completed
- [ ] Export compliance: No non-exempt encryption
- [ ] TestFlight internal test passed — [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md)
- [ ] Submitted for review — review notes in [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)

Full walkthrough: [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md)
