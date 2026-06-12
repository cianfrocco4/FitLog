# App Store Submission Guide — The Workout Log

Step-by-step guide to publish **The Workout Log** (`com.acianfrocco.FitLog`) v1.0 to the App Store.

## Prerequisites

- [ ] Apple Developer Program membership (team `N7HAUF9TT9`)
- [ ] App record created in [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Privacy policy and support pages live (see [Hosting](#hosting-privacy--support-pages))
- [ ] Release build archived and uploaded (see [Archive & upload](#archive--upload))

---

## 1. Create App Store Connect record

1. App Store Connect → **Apps** → **+** → **New App**
2. **Platforms:** iOS  
3. **Name:** The Workout Log  
4. **Primary language:** English (U.S.)  
5. **Bundle ID:** `com.acianfrocco.FitLog`  
6. **SKU:** `fitlog-ios-1` (any unique string)  
7. **User Access:** Full Access  

### App Information

| Field | Value |
|-------|--------|
| Name | The Workout Log |
| Subtitle | Log lifts. Rest. Repeat. |
| Category (Primary) | Health & Fitness |
| Category (Secondary) | Optional — Lifestyle |
| Content Rights | Does not contain third-party content requiring rights |
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

Enter these in App Store Connect → App Information → **Privacy Policy URL** and **Support URL**.

---

## 3. Privacy Nutrition Labels

App Store Connect → App Privacy → **Get Started**

### Data Used to Track You
**None**

### Data Linked to You

| Data type | Purpose | Notes |
|-----------|---------|-------|
| Health & Fitness | App Functionality | Workout logs; HealthKit only when user enables sync |
| User Content | App Functionality | Progress photos, notes — stored locally |
| Identifiers | App Functionality | Sign in with Apple (optional) — anonymous ID on device |

### Data Not Linked to You
**None** (unless you add analytics later)

### Third-party data processing
When user uses AI Coach or form guides, exercise names and workout structure are sent to your Render proxy → OpenAI / MuscleWiki. Disclose under **Data Types** → **Other Data** or in app privacy details as processed on your behalf, not linked to identity.

---

## 4. Age rating

Complete the questionnaire. Typical answers for this app:

- Cartoon/fantasy violence: None
- Realistic violence: None
- Sexual content: None
- Profanity: None
- Medical/treatment info: None (fitness logging only)
- Unrestricted web access: **No**
- User-generated content: **No** (or No if photos are local-only)

Expected rating: **4+**

---

## 5. Export compliance

When uploading the build, answer:

- **Uses encryption?** Yes (HTTPS)
- **Exempt?** Yes — `ITSAppUsesNonExemptEncryption = false` in Info.plist  
  Or answer **No** to non-exempt encryption in the compliance dialog.

---

## 6. Release secrets (before archive)

```bash
cp Config/Secrets.release.xcconfig.example Config/Secrets.release.xcconfig
# Edit Config/Secrets.release.xcconfig — set FITLOG_PROXY_SHARED_SECRET to match Render
# (Only required when Render /health shows authRequired: true)
```

Verify proxy:

```bash
curl https://the-workout-log.onrender.com/health
```

---

## 7. Archive & upload

### Xcode

1. Select **Any iOS Device (arm64)** as destination
2. **Product → Archive** (Release configuration)
3. Organizer → **Distribute App** → **App Store Connect** → **Upload**
4. Wait for processing (email when ready)

### Command line (optional)

```bash
xcodebuild archive \
  -scheme FitLog \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/FitLog.xcarchive

xcodebuild -exportArchive \
  -archivePath build/FitLog.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```

---

## 8. Screenshots

Required because the app targets iPhone **and** iPad (`TARGETED_DEVICE_FAMILY = 1,2`).

| Device class | Simulator | ASC slot |
|--------------|-----------|----------|
| 6.7" iPhone | iPhone 16 Pro Max | 6.7" Display |
| 6.1" iPhone | iPhone 16 | 6.1" Display |
| 13" iPad | iPad Pro 13-inch (M4) | 13" Display |

Run the helper script for a baseline home screenshot:

```bash
chmod +x scripts/capture-app-store-screenshots.sh
./scripts/capture-app-store-screenshots.sh
```

Manually capture additional screens: active workout, rest timer, History overview, Coach.

---

## 9. TestFlight

1. App Store Connect → **TestFlight** → select build **1.0 (1)**
2. Add internal testers (your Apple ID)
3. Install via TestFlight app
4. Complete [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) on device
5. Fix any issues; bump `CURRENT_PROJECT_VERSION` and re-upload if needed

---

## 10. Submit for review

1. App Store Connect → **App Store** tab → **+ Version** → `1.0`
2. Select the uploaded build
3. Fill screenshots, description, keywords, support URL, privacy URL
4. **App Review Information:**
   - Contact: Anthony Cianfrocco, acianfrocco@gmail.com
   - Notes:

```
Sign in with Apple is optional — tap "Continue without signing in" on the login screen.

AI Coach and form guide features are optional and require network access to our proxy
(https://the-workout-log.onrender.com). Core workout logging works fully offline.

HealthKit sync is optional and only activated when the user enables it in More → Data & Integrations.

Demo account not required — reviewer can start a workout from Home without signing in.
```

5. **Submit for Review**

Review typically takes 24–48 hours.

---

## Quick reference

| Item | Location |
|------|----------|
| Metadata copy | [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) |
| ASC checklist | [app-store-connect-checklist.md](app-store-connect-checklist.md) |
| Smoke test | [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) |
| Build verification | [BUILD_CONFIG_VERIFICATION.md](BUILD_CONFIG_VERIFICATION.md) |
| Privacy policy source | [PRIVACY_POLICY.md](../PRIVACY_POLICY.md) |
