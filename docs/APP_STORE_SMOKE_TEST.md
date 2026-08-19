# App Store Smoke Test Checklist — Workout Log AI

Run on a **physical device** with a **Release** or TestFlight build before submission. Re-verify after major changes (SwiftData migrations through **V6**, Premium, widgets).

## Automated (simulator)

| Check | Notes |
|-------|--------|
| Debug build compiles | `xcodebuild -scheme FitLog -destination 'platform=iOS Simulator,id=<iPhone>' build` |
| Unit tests | `FitLogTests` including SwiftData V5→V6, readiness, entitlement, history range |
| UI journeys | `FitLogUITests` plus **daily living** (`scripts/run-daily-living-users.sh`) to grow History and write likes/dislikes/bugs into `INBOX.md`. Snapshot UI tests stay on a Mac / `fitlog-mac` (not GitHub iOS CI). See [AUTOMATED_USER_TESTING.md](AUTOMATED_USER_TESTING.md). |
| StoreKit config | FitLog scheme → Run → StoreKit Configuration = `Configuration.storekit` |
| RevenueCat SPM | `purchases-ios-spm` resolved (see Package.resolved) |

Exploratory bot (taps like a free user, screenshots, optional small UX PR): [automation-prompts/exploratory-user-testing.md](automation-prompts/exploratory-user-testing.md).

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
- [ ] More → Subscription **Legal** section: **Terms of Use** and **Privacy Policy** open in Safari (EULA + GitHub Pages policy)
- [ ] More → **Legal & Support**: Terms of Use, Privacy Policy, and Support open in Safari
- [ ] Paywall is StoreKit **SubscriptionStoreView** (More → Subscription → Upgrade, or any Premium gate)
- [ ] Store view shows subscription **title**, **duration**, and **price** on iPhone and iPad (not an empty / “Plans unavailable” only screen)
- [ ] Restore purchases control is visible on the paywall
- [ ] Paywall **Terms of Use** and **Privacy Policy** links open the same URLs (Safari 200)
- [ ] Eligible sandbox Apple ID: purchase unlocks Coach send + program generate + trends + export + extended history
- [ ] **Manage Subscription** opens for active subscribers
- [ ] Comp path: copy App User ID → RevenueCat promotional entitlement → Restore / Refresh
- [ ] RevenueCat dashboard: production `appl_` key, Current offering `default`, products attached to `premium`

### AI gating & proxy cost controls
- [ ] Free: Coach composer blocked; paywall on send attempt
- [ ] Free: program generate / Quick Start shows paywall (not silent error-only)
- [ ] Free: Suggest exercises menu does **not** say “(AI)” unless entitled
- [ ] Paid: Coach and program generation succeed when proxy is up (Release secret wired)
- [ ] Proxy without secret → **401**; burst chat → **429** (see [SHIP_CHECKLIST.md](SHIP_CHECKLIST.md) §2b)
- [ ] Daily AI soft-limit copy appears after heavy local use (“Daily AI limit reached…”)

### Erase / privacy
- [ ] **Erase all app data** (local-only / not signed in) clears workouts, Coach chats, readiness, body metrics, and progress photos
- [ ] Confirmation copy mentions Apple Health workouts may remain in Health

### Account deletion (Guideline 5.1.1(v) — signed in)
- [ ] Sign in with Apple (or create a new SIWA account)
- [ ] More shows an **Account** section with **Delete Account** (also More → Account → Delete Account)
- [ ] Confirming Delete Account returns to the sign-in screen
- [ ] After deletion, local workouts / Coach chats are gone (Sign Out alone must **not** erase workouts)
- [ ] Copy states App Store subscriptions are not canceled automatically

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
- [ ] Signed-in users do **not** see only “Erase all app data” in place of Delete Account

## Sign-off

| Role | Name | Date | Build |
|------|------|------|-------|
| Developer | | | |

## Related

- [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)
- [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)
- [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md)
