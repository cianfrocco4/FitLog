# App Store Submission Guide — Workout Log AI

Step-by-step guide to publish **Workout Log AI** (`com.acianfrocco.FitLog`) to the App Store with freemium Premium subscriptions.

## Prerequisites

- [ ] Apple Developer Program membership (team `N7HAUF9TT9`)
- [ ] App record created in [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Subscription products + RevenueCat configured — see [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)
- [ ] Privacy policy and support pages live (see [Hosting](#hosting-privacy--support-pages))
- [ ] Release build archived and uploaded (see [Archive & upload](#archive--upload))

---

## 1. Create App Store Connect record

1. App Store Connect → **Apps** → **+** → **New App**
2. **Platforms:** iOS  
3. **Name:** Workout Log AI  
4. **Primary language:** English (U.S.)  
5. **Bundle ID:** `com.acianfrocco.FitLog`  
6. **SKU:** `fitlog-ios-1` (any unique string)  
7. **User Access:** Full Access  

### App Information

| Field | Value |
|-------|--------|
| Name | Workout Log AI |
| Subtitle | Train smarter. Recover better. |
| Category (Primary) | Health & Fitness |
| Category (Secondary) | Optional — Lifestyle |
| Content Rights | **Yes** if MuscleWiki form media ships (confirm you have rights via API); otherwise No — see SHIP_CHECKLIST §1a |
| Copyright | `2026 Anthony Cianfrocco` (on the version page) |
| Price | **Free** (Premium via IAP) |
| Age Rating | Complete questionnaire (see [Age rating](#age-rating)) |

Copy **Description**, **Keywords**, **Promotional Text**, and **What's New** from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md).

---

## 2. Hosting privacy & support pages

### GitHub Pages (recommended)

1. Push repo to GitHub (`cianfrocco4/FitLog` or your fork)
2. Repo **Settings** → **Pages** → Source: **Deploy from branch**
3. Branch: `main`, folder: **`/docs`**
4. Wait for deploy; URLs will be:
   - Privacy: `https://<username>.github.io/FitLog/privacy-policy.html`
   - Support: `https://<username>.github.io/FitLog/support.html`
   - Terms of Use (hosted pointer): `https://<username>.github.io/FitLog/terms-of-use.html`

Enter Privacy and Support in App Store Connect → App Information. Paste Apple’s Standard EULA URL into the **App Description** (Guideline 3.1.2(c)):

`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

Confirm hosted HTML matches [PRIVACY_POLICY.md](../PRIVACY_POLICY.md) (subscriptions, readiness HealthKit reads, medical disclaimer).

---

## 3. Privacy Nutrition Labels

App Store Connect → App Privacy → **Get Started**

### Data Used to Track You
**None**

### Data Linked to You

| Data type | Purpose | Notes |
|-----------|---------|-------|
| Health & Fitness | App Functionality | Workout logs; readiness reads (sleep, HRV, resting HR); HealthKit sync when enabled |
| Purchases | App Functionality | Auto-renewable subscriptions / lifetime via Apple + RevenueCat |
| User Content | App Functionality | Progress photos, notes — stored locally |
| Identifiers | App Functionality | Sign in with Apple (optional); RevenueCat App User ID |
| Other Data | App Functionality | Workout text sent to AI proxy when Premium user invokes Coach / form guides |

### Data Not Linked to You
**None** required for the local Logger analytics sink (no third-party tracking SDK).

See also [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md).

---

## 4. Subscriptions (Guideline 3.1)

Before review:

1. Complete **Paid Apps Agreement**, tax, and banking in App Store Connect.
2. Create subscription group **Workout Log AI Premium** and products — [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md).
3. Upload a **Review Information screenshot** on each auto-renewable SKU and **attach the group to this version**.
4. Confirm `REVENUECAT_API_KEY` (public `appl_…` key) is in the **Release** archive (`Info.plist`).
5. Paywall is `SubscriptionStoreView` with Restore, Privacy Policy, and Terms of Use (Apple Standard EULA).
6. App Description must include the EULA URL — [APP_STORE_METADATA.md](../APP_STORE_METADATA.md).
7. After a 2.1(b) / 3.1.2(c) rejection, follow [APP_REVIEW_RESOLUTION.md](APP_REVIEW_RESOLUTION.md) (new binary + Resolution Center reply + screen recording).

---

## 5. Age rating

Complete the questionnaire. Typical answers for this app:

- Cartoon/fantasy violence: None
- Realistic violence: None
- Sexual content: None
- Profanity: None
- Medical/treatment info: None (fitness logging / readiness only — not medical advice)
- Unrestricted web access: **No**
- User-generated content: **No** (or No if photos are local-only)

Expected rating: **4+**

---

## 6. Export compliance

When uploading the build, answer:

- **Uses encryption?** Yes (HTTPS)
- **Exempt?** Yes — `ITSAppUsesNonExemptEncryption = false` in Info.plist  
  Or answer **No** to non-exempt encryption in the compliance dialog.

---

## 7. Release secrets (before archive)

```bash
cp Config/Secrets.release.xcconfig.example Config/Secrets.release.xcconfig
# Edit Config/Secrets.release.xcconfig — set FITLOG_PROXY_SHARED_SECRET to match Render
# Info.plist expands $(FITLOG_PROXY_SHARED_SECRET) at archive time (not INFOPLIST_KEY_)
# (Only required when Render /health shows authRequired: true)
```

Verify proxy:

```bash
curl https://the-workout-log.onrender.com/health
```

Confirm App Group `group.com.acianfrocco.FitLog.shared` and HealthKit are enabled for the App ID in the Developer portal (required for readiness widgets + Health).

---

## 8. Archive & upload

### Xcode

1. Select **Any iOS Device (arm64)** as destination
2. **Product → Archive** (Release configuration)
3. Organizer → **Distribute App** → **App Store Connect** → **Upload**
4. Wait for processing (email when ready)

---

## 9. Screenshots

Required because the app targets iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = 1,2`).

| Device class | Simulator | ASC slot |
|--------------|-----------|----------|
| 6.7" iPhone | iPhone 16 Pro Max | 6.7" Display |
| 6.1" iPhone | iPhone 16 | 6.1" Display |
| 13" iPad | iPad Pro 13-inch (M4) | 13" Display |

Capture: Home + readiness, paywall, Coach, History, home-screen widget.

---

## 10. TestFlight

1. App Store Connect → **TestFlight** → select the uploaded build
2. Add internal testers (your Apple ID)
3. Install via TestFlight app
4. Complete [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) on device (free / paid / comped)
5. Fix any issues and re-upload. If Apple already approved this marketing version, bump `MARKETING_VERSION` (ITMS-90186 / ITMS-90062) and create a matching App Store Connect version. Otherwise increment `CURRENT_PROJECT_VERSION` only.

---

## 11. Submit for review

1. App Store Connect → **App Store** tab → version
2. Select the uploaded build
3. Fill screenshots, description (must include Terms of Use / EULA URL), keywords, support URL, privacy URL
4. **In-App Purchases and Subscriptions** — attach monthly + annual products to this version
5. **App Review Information** — paste notes from [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)

5. **Submit for Review**

---

## Quick reference

| Item | Location |
|------|----------|
| Metadata copy | [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) |
| Rejection / IAP resubmit | [APP_REVIEW_RESOLUTION.md](APP_REVIEW_RESOLUTION.md) |
| RevenueCat / IAP | [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md) |
| ASC checklist | [app-store-connect-checklist.md](app-store-connect-checklist.md) |
| Smoke test | [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) |
| Build verification | [BUILD_CONFIG_VERIFICATION.md](BUILD_CONFIG_VERIFICATION.md) |
| Privacy policy source | [PRIVACY_POLICY.md](../PRIVACY_POLICY.md) |
