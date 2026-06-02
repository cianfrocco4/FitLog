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

1. Set `FITLOG_PROXY_SHARED_SECRET` in **Release** configuration (Xcode build setting or scheme environment) to the same value as Render (`FITLOG_PROXY_SHARED_SECRET` on the server).
2. Empty string in `Info.plist` is intentional for local dev; Release archive must inject the real secret or AI/form-guide requests return **401**.

Verify in Render dashboard: **Environment** → `FITLOG_PROXY_SHARED_SECRET` matches the archived app.

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
