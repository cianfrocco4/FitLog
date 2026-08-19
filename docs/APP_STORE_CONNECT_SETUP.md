# App Store Connect — Copy-Paste Setup

Use this when creating the app record in [App Store Connect](https://appstoreconnect.apple.com).

## App record

| Field | Value |
|-------|--------|
| Platform | iOS |
| Name | Workout Log AI |
| Primary Language | English (U.S.) |
| Bundle ID | `com.acianfrocco.FitLog` |
| SKU | `fitlog-ios-1` |

## URLs (after GitHub Pages deploy)

| Field | URL |
|-------|-----|
| Privacy Policy | `https://cianfrocco4.github.io/FitLog/privacy-policy.html` |
| Support | `https://cianfrocco4.github.io/FitLog/support.html` |
| Terms of Use (EULA) in **App Description** | `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/` |
| License Agreement (App Information) | Apple Standard EULA (do not attach a custom EULA) |
| Marketing | Optional — same support URL or GitHub repo |

Replace `cianfrocco4` with your GitHub username if different.

**Guideline 3.1.2(c):** the Privacy Policy field and a functional Terms of Use (EULA) link in the App Description are both required for auto-renewable subscriptions. Copy the Description from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) — it includes both URLs.

## Metadata (from APP_STORE_METADATA.md)

**Subtitle:** Train smarter. Recover better.

**Keywords:** gym,fitness,strength,readiness,HRV,sleep,AI,coach,hypertrophy,training,lifting,periodization

**Category:** Health & Fitness

**What's New (1.0.1):** see [APP_STORE_METADATA.md](../APP_STORE_METADATA.md).

## Subscriptions

See [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md) for product IDs, entitlement `premium`, and offering setup.

## Build assignment

- Version: `MARKETING_VERSION` in `FitLog.xcodeproj` (currently **1.0.1**). This becomes `CFBundleShortVersionString`.
- After Apple **approves** a version, that train is closed. Bump `MARKETING_VERSION` on the app, widgets, and Live Activity targets (e.g. 1.0 → 1.0.1) **before** the next Xcode Cloud upload. Reusing a closed version fails with **ITMS-90186** / **ITMS-90062**.
- Then create a matching iOS version in App Store Connect (App Store tab → **+ Version**) so the new build can be submitted.
- Build: Xcode Cloud auto-increments `CFBundleVersion`. For local archives, increment `CURRENT_PROJECT_VERSION` for each re-upload.
- Archive: Release configuration with `REVENUECAT_API_KEY` set

## Checklist

- [ ] App record created (name **Workout Log AI**)
- [ ] Privacy Policy URL live and entered in App Information
- [ ] **App Description includes Terms of Use (EULA) URL** (Apple Standard EULA) — [APP_STORE_METADATA.md](../APP_STORE_METADATA.md)
- [ ] Screenshots uploaded (6.7", 6.1", iPad 13")
- [ ] Privacy labels completed — [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)
- [ ] Age rating completed
- [ ] Export compliance: No non-exempt encryption
- [ ] Subscriptions attached to **this version** + RevenueCat Current offering verified
- [ ] IAP Review Information screenshot uploaded per subscription SKU
- [ ] TestFlight matrix passed — [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md)
- [ ] Submitted for review — notes in [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)

Full walkthrough: [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md)
