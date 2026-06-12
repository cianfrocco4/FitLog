# FitLog App Store Connect Checklist

Use this checklist when submitting **The Workout Log** (FitLog) to App Store Connect. These items are configured in App Store Connect and Xcode, not in app code.

## URLs & contact

| Field | Value |
|-------|--------|
| Privacy Policy URL | Host `docs/privacy-policy.html` (GitHub Pages or your site) |
| Support URL | Host `docs/support.html` |
| Marketing URL | Optional |
| Support email | `acianfrocco@gmail.com` |

Confirm both HTML pages are live before submission.

## Privacy Nutrition Labels

Match the revised in-app policy (`PRIVACY_POLICY.md` / `docs/privacy-policy.html`):

- **Data used to track you:** None
- **Data linked to you:** Health & Fitness (workout logs, HealthKit sync when enabled), User Content (notes, progress photos) — only if you declare collection; adjust to match actual HealthKit usage
- **Data not linked to you:** None required unless analytics are added later
- **Third-party processing:** OpenAI (AI coach) and MuscleWiki (form guides) via your Render proxy — disclose as processed on your behalf, not linked to identity when using proxy-only flow

## Export compliance

- `ITSAppUsesNonExemptEncryption = false` is set in `FitLog/Info.plist` — answer **No** to non-exempt encryption in App Store Connect.

## Release build: proxy secret

Before archiving for App Store:

1. Copy `Config/Secrets.release.xcconfig.example` → `Config/Secrets.release.xcconfig` (gitignored).
2. Set `FITLOG_PROXY_SHARED_SECRET` to match Render when `/health` reports `"authRequired": true`.
3. Release builds load secrets via [Config/Release.xcconfig](../Config/Release.xcconfig) → `INFOPLIST_KEY_FITLOG_PROXY_SHARED_SECRET`.

Verify proxy:

```bash
curl https://the-workout-log.onrender.com/health
```

Current production check (2026-06-11): `authRequired: false` — secret optional until enabled on Render.

## Full submission walkthrough

See [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md) for step-by-step ASC setup, TestFlight, and review submission.

See [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md) for privacy labels, age rating, and review notes.

See [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) for pre-submission device testing.

## Screenshots & metadata

- [ ] iPhone 6.7" and 6.1" screenshots (required sizes per ASC)
- [ ] App name: **The Workout Log**
- [ ] Subtitle, description, keywords
- [ ] Age rating questionnaire (fitness app, no unrestricted web)
- [ ] Category: Health & Fitness

## Capabilities verified in project

- [x] `PrivacyInfo.xcprivacy` in app bundle (see `docs/BUILD_CONFIG_VERIFICATION.md`)
- [x] HealthKit entitlement (read/write usage strings in Info.plist)
- [x] Sign in with Apple (optional auth)
- [x] App Intents use standard `UserDefaults` (no App Group required for v1)

## TestFlight → Production

1. Archive with **Release** scheme and valid proxy secret.
2. Upload to App Store Connect.
3. Complete TestFlight internal testing (finish workout, backup/restore, HealthKit opt-in, AI coach if enabled).
4. Submit for review with privacy labels and URLs above.
