# App Store Smoke Test Checklist

Run on a **physical device** with a **Release** or TestFlight build before submission. Automated checks below were verified in CI/local simulator on 2026-06-11.

## Automated (simulator)

| Check | Status | Notes |
|-------|--------|-------|
| Debug build compiles | Pass | `xcodebuild -scheme FitLog -configuration Debug` |
| Unit tests (187) | Pass | `FitLogTests` including SwiftData V2→V5 migrations |
| UI launch smoke test | Pass | `FitLogUITests/testExample` — tab bar appears |
| Render proxy `/health` | Pass | `authRequired: false` at time of check; enable secret on Render when ready |

## Manual device checklist

### Core workout flow
- [ ] Start workout from Home (template or scratch)
- [ ] Log at least one set with weight and reps
- [ ] Start rest timer; confirm notification fires when allowed
- [ ] Finish workout; confirm completion summary appears
- [ ] Confirm session appears in **History → Sessions**

### History (v1.0 module)
- [ ] **Overview** tab: KPI tiles and charts render with data
- [ ] **Sessions** tab: completed workout listed; tap opens detail
- [ ] **Explore** tab: exercise/muscle stats load
- [ ] Date range filter changes overview data

### Rest timer / Live Activity
- [ ] Collapsed workout bar visible during active session
- [ ] Live Activity appears on Lock Screen / Dynamic Island (device with support)

### HealthKit (optional)
- [ ] Enable sync in **More → Data & Integrations**
- [ ] Complete workout writes to Health (if enabled)
- [ ] Deny permission — app continues without crash

### Backup & restore
- [ ] Export backup from **More → Data & Integrations**
- [ ] Erase app data (or reinstall) and restore from backup
- [ ] Workouts and programs return correctly

### AI / form guide (optional)
- [ ] Coach tab loads; send a message (proxy cold start may take ~30s on free tier)
- [ ] Form guide on an exercise: loads video or falls back to heuristic tips
- [ ] Airplane mode: core logging still works; AI shows graceful fallback

### Auth & onboarding
- [ ] Fresh install: onboarding can be completed or skipped
- [ ] Sign in with Apple optional; app usable without sign-in
- [ ] Sign out does not delete workout data

## Sign-off

| Role | Name | Date | Build |
|------|------|------|-------|
| Developer | | | 1.0 (1) |
