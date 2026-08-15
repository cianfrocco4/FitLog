# Workout Log AI — App Store Connect Checklist

Use this checklist when submitting **Workout Log AI** (FitLog) to App Store Connect. These items are configured in App Store Connect and Xcode, not only in app code.

## URLs & contact

| Field | Value |
|-------|--------|
| Privacy Policy URL | `https://cianfrocco4.github.io/FitLog/privacy-policy.html` |
| Support URL | `https://cianfrocco4.github.io/FitLog/support.html` |
| Terms of Use (EULA) in App Description | `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` |
| Marketing URL | Optional |
| Support email | `acianfrocco@gmail.com` |

Confirm privacy, support, and terms HTML pages are live and say **Workout Log AI** (subscriptions + readiness) before submission. The App Description **must** include the Apple Standard EULA URL (Guideline 3.1.2(c)).

## Privacy Nutrition Labels

Match [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md) / [PRIVACY_POLICY.md](../PRIVACY_POLICY.md):

- **Data used to track you:** None
- **Data linked to you:** Health & Fitness (workouts; readiness reads: sleep, HRV, resting HR; optional sync), Purchases (subscriptions), User Content (notes, photos), Identifiers (optional SIWA + RevenueCat App User ID), Other Data (AI proxy when Premium)
- **Data not linked to you:** None required unless a third-party analytics SDK is added later

## Subscriptions

- [ ] Paid Apps Agreement + tax/banking complete
- [ ] Subscription group **Workout Log AI Premium**
- [ ] Products: `workoutlogai_premium_monthly`, `workoutlogai_premium_annual` (optional lifetime only if created **and** submitted)
- [ ] Each SKU: localization + **Review Information screenshot** (status not Missing Metadata)
- [ ] Products **attached to this iOS version** (In-App Purchases and Subscriptions)
- [ ] RevenueCat entitlement `premium` + **Current** offering — [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)
- [ ] `REVENUECAT_API_KEY` present in Release archive
- [ ] Sandbox purchase + Restore verified on device
- [ ] App Description includes Terms of Use (EULA) URL

## Export compliance

- `ITSAppUsesNonExemptEncryption = false` is set in `FitLog/Info.plist` — answer **No** to non-exempt encryption in App Store Connect.

## Release build: proxy secret

Before archiving for App Store:

1. Copy `Config/Secrets.release.xcconfig.example` → `Config/Secrets.release.xcconfig` (gitignored).
2. Set `FITLOG_PROXY_SHARED_SECRET` to match Render when `/health` reports `"authRequired": true`.
3. Release builds load secrets via [Config/Release.xcconfig](../Config/Release.xcconfig).

## Capabilities

- [x] HealthKit entitlement (readiness reads + optional workout sync)
- [x] App Group `group.com.acianfrocco.FitLog.shared` (readiness / plan widgets)
- [x] Sign in with Apple (optional auth)
- [x] `PrivacyInfo.xcprivacy` in app bundle (see [BUILD_CONFIG_VERIFICATION.md](BUILD_CONFIG_VERIFICATION.md))

## Screenshots & metadata

- [ ] iPhone 6.7" and 6.1" screenshots (required sizes per ASC)
- [ ] App name: **Workout Log AI**
- [ ] Subtitle, description (with EULA URL), keywords from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md)
- [ ] Age rating questionnaire (fitness app, no unrestricted web)
- [ ] Category: Health & Fitness

## TestFlight → Production

1. Archive with **Release** scheme (RC key + proxy secret as needed).
2. Upload to App Store Connect.
3. Complete TestFlight matrix in [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md).
4. Submit for review with privacy labels and URLs above.

Full walkthrough: [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md).
