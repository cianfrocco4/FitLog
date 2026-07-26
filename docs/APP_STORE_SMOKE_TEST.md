# App Store Smoke Test Checklist — Workout Log AI

Run on a **physical device** with a **Release** or TestFlight build before submission. Re-verify after major changes (SwiftData migrations through **V6**, Premium, widgets).

## Automated (simulator)

| Check | Notes |
|-------|--------|
| Debug build compiles | `xcodebuild -scheme FitLog -destination 'platform=iOS Simulator,id=<iPhone>' build` |
| Unit tests | `FitLogTests` including SwiftData V5→V6, readiness, entitlement, history range |
| StoreKit config | FitLog scheme → Run → StoreKit Configuration = `Configuration.storekit` |
| RevenueCat SPM | `purchases-ios-spm` resolved (see Package.resolved) |

## Manual device checklist

### Core workout flow (free)
- [ ] Start workout from Home (template or scratch)
- [ ] Log at least one set with weight and reps
- [ ] Start rest timer; confirm notification fires when allowed
- [ ] Finish workout; confirm session appears in **History → Sessions**
- [ ] Widget / Home readiness updates after finish (when App Group works)

### Readiness (free)
- [ ] Home shows today's readiness without prompting HealthKit on appear
- [ ] **Connect Apple Health** CTA when not yet attempted
- [ ] After connect with no metrics: informational no-data state (not a dead-end Connect button)
- [ ] Training-load-only score is sensible (not a red ~11)
- [ ] Readiness **trends** show Premium upsell when free

### History freemium
- [ ] Default range is 14 days (or 7 if chosen)
- [ ] Tapping 30/90/YTD as free user shows paywall and **keeps** prior free range
- [ ] Heatmap / advanced charts gated for free users
- [ ] Exercise detail **All time** gated for free users

### Premium / subscriptions
- [ ] More → Subscription shows Free / Active correctly
- [ ] Paywall loads packages (or clear “unavailable” if RC not configured)
- [ ] Sandbox purchase unlocks Coach send + program generate + trends + export + extended history
- [ ] **Restore purchases** works on paywall
- [ ] **Manage Subscription** opens for active subscribers
- [ ] Comp path: copy App User ID → RevenueCat promotional entitlement → Restore / Refresh

### AI gating
- [ ] Free: Coach composer blocked; paywall on send attempt
- [ ] Free: program generate / Quick Start shows paywall (not silent error-only)
- [ ] Free: Suggest exercises menu does **not** say “(AI)” unless entitled
- [ ] Paid: Coach and program generation succeed when proxy is up

### Widgets
- [ ] Add Readiness widget to Home Screen
- [ ] Shows score / plan after app launch or workout finish
- [ ] Quick-log deep link opens app to log / active workout

### HealthKit sync (optional, separate from readiness)
- [ ] Enable sync in **More → Data & Integrations**
- [ ] Complete workout writes to Health (if enabled)
- [ ] Deny permission — app continues without crash

### Backup & restore
- [ ] Export backup from **More → Data & Integrations**
- [ ] Erase / reinstall and restore from backup
- [ ] Workouts and programs return; V5→V6 migration path does not lose data

### Auth & onboarding
- [ ] Fresh install: onboarding can be completed or skipped; Premium page dismissible
- [ ] Sign in with Apple optional; app usable without sign-in
- [ ] Sign out does not delete workout data; RC logOut when entitlement store is passed

## Sign-off

| Role | Name | Date | Build |
|------|------|------|-------|
| Developer | | | |

## Related

- [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)
- [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)
- [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md)
