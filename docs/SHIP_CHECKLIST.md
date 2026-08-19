# Ship checklist — Workout Log AI (Phase 1 + 2)

Branch: `feature/phase-1-workout-log-ai` → merge to `main` before / with submission so GitHub Pages (`docs/`) stays aligned.

## 1. Xcode Cloud → TestFlight

- [x] Xcode Cloud built `**feature/phase-1-workout-log-ai**` successfully  
- [x] Install **that** TestFlight build on a physical device  
- [x] Spot-check ([APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md)): free log + readiness + history clamp + Coach paywall; Premium unlock + Restore; widget  


| Build number | Date | Tester | Pass? |
| ------------ | ---- | ------ | ----- |
|              |      |        |       |


## 2. Merge to `main`

- [x] Feature branch contains Phase 1 freemium + Phase 2 on-device AI  
- [x] Merged `feature/phase-1-workout-log-ai` → `main` (`fdd1a61`)  
- [x] `main` pushed  
- [x] **GitHub Pages** enabled (verified live 2026-07-26; see [Enable GitHub Pages](#enable-github-pages) below)  

## Enable GitHub Pages

The HTML files already live on `main` under `docs/privacy-policy.html`, `docs/support.html`, and `docs/terms-of-use.html`. A **404** means Pages is off or pointed at the wrong branch/folder — not that the files are missing from git.

### Click path

1. Open the repo: [https://github.com/cianfrocco4/FitLog](https://github.com/cianfrocco4/FitLog)
2. Click **Settings** (repo toolbar; you need admin on the repo).
3. Left sidebar → **Pages** (under “Code and automation”).
4. Under **Build and deployment** → **Source**, choose **Deploy from a branch** (not “GitHub Actions” unless you already have a Pages workflow).
5. **Branch** row:
  - Branch: `**main**`
  - Folder: `**/docs**` (not `/ (root)`)
6. Click **Save**.
7. Wait 1–3 minutes. The Pages settings page should show something like:
  **Your site is live at** `https://cianfrocco4.github.io/FitLog/`
8. Open these URLs (hard-refresh if you still see 404):
  - Privacy: [https://cianfrocco4.github.io/FitLog/privacy-policy.html](https://cianfrocco4.github.io/FitLog/privacy-policy.html)  
  - Support: [https://cianfrocco4.github.io/FitLog/support.html](https://cianfrocco4.github.io/FitLog/support.html)
  - Terms of Use: [https://cianfrocco4.github.io/FitLog/terms-of-use.html](https://cianfrocco4.github.io/FitLog/terms-of-use.html)

### Why the path looks like that


| Setting                         | Effect                                        |
| ------------------------------- | --------------------------------------------- |
| Branch `main`                   | Publishes whatever is on `main`               |
| Folder `/docs`                  | Site root = contents of the `docs/` directory |
| File `docs/privacy-policy.html` | Public URL = `…/FitLog/privacy-policy.html`   |
| File `docs/support.html`        | Public URL = `…/FitLog/support.html`          |
| File `docs/terms-of-use.html`   | Public URL = `…/FitLog/terms-of-use.html`     |


If you picked folder `**/ (root)**` by mistake, the URL would be  
`https://cianfrocco4.github.io/FitLog/docs/privacy-policy.html` instead — don’t use that for App Store Connect; switch Source folder back to `**/docs**`.

### After it’s live — App Store Connect

App Store Connect → your app → **App Information**:

- **Privacy Policy URL:** `https://cianfrocco4.github.io/FitLog/privacy-policy.html`
- **Support URL:** `https://cianfrocco4.github.io/FitLog/support.html`
- **App Description Terms of Use (EULA):** `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

(Also used on the paywall, More → Subscription, and More → Legal & Support.)

### If it still 404s


| Check               | What to do                                                                                                                    |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Wrong account/repo  | Confirm you’re on **cianfrocco4/FitLog**, not a fork without Pages                                                            |
| Deploy not finished | Settings → Pages → look for a green “live” note; wait and retry                                                               |
| Files not on `main` | On GitHub, open `main` → `docs/` → confirm both `.html` files exist                                                           |
| Private repo        | Free GitHub only allows Pages on public repos (or use GitHub Pro). Make the repo public, or host the two HTML files elsewhere |
| Cached 404          | Try a private/incognito window or append `?v=2` once                                                                          |
| Actions failed      | If Source is “GitHub Actions”, either fix that workflow or switch back to **Deploy from a branch**                            |


## 2b. API cost / proxy (before public launch)

Hardened proxy code lives in `[backend/server.js](../backend/server.js)`. App production base URL: `https://the-workout-log.onrender.com` (`FitLog/Info.plist` → `FITLOG_AI_BASE_URL` / `FITLOG_FORM_GUIDE_BASE_URL`). Deploy the latest `backend/` to Render **before** verifying secrets.

Also see [BUILD_CONFIG_VERIFICATION.md](BUILD_CONFIG_VERIFICATION.md), [backend/README.md](../backend/README.md), [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md) §7.

### Checklist

- [x] Deploy hardened `backend/` to Render (root directory `backend`)  
- [x] Render `/health` shows `"authRequired": true`  
- [x] `FITLOG_PROXY_SHARED_SECRET` matches Release archive (`Config/Secrets.release.xcconfig` or Xcode Cloud secret)  
- [x] OpenAI project hard monthly budget + email alerts (~50% / 80% / 100%)  
- [x] MuscleWiki plan quotas / alerts confirmed  
- [x] Prefer paid always-on Render (or equivalent) — avoid free sleep for launch  
- [x] Hit proxy **without** secret → **401** (or **503** if secret required but missing)  
- [x] Burst chat → **429**; oversized body → **400**  
- [x] Release/TestFlight AI Coach + form guide still work **with** secret  

### 0. Deploy the hardened backend

1. Push the branch that contains the updated `backend/server.js`.
2. Render → Web Service → **Root Directory** = `backend` → redeploy.
3. Confirm the service is healthy after deploy (next step).

### 1. Render env + `/health` → `"authRequired": true`

Render → service → **Environment** — set at least:


| Variable                     | Value                                                               |
| ---------------------------- | ------------------------------------------------------------------- |
| `OPENAI_API_KEY`             | OpenAI key for this proxy only                                      |
| `MUSCLEWIKI_API_KEY`         | MuscleWiki key (`mw_…`)                                             |
| `FITLOG_PROXY_SHARED_SECRET` | Long random secret (e.g. `openssl rand -hex 32`)                    |
| `REQUIRE_PROXY_SECRET`       | `1` (recommended — fail closed even if `NODE_ENV` isn’t production) |
| `NODE_ENV`                   | `production` (if Render doesn’t already set it)                     |


Optional: `ALLOW_FORM_GUIDE_STREAM=0` to disable branded video proxying (cuts MuscleWiki bandwidth risk; search/exercise metadata still work).

Redeploy, then:

```bash
curl -s https://the-workout-log.onrender.com/health
```

Expect:

```json
{"ok":true,"service":"fitlog-proxy","formGuide":true,"authRequired":true,"streamEnabled":true}
```

If `authRequired` is `false`, the secret is missing or the deploy didn’t pick up env vars.

### 2. Same secret in the iOS Release archive

The app sends header `X-FitLog-Proxy-Secret` at **runtime** from Info.plist (`FitLogProxyConfig`). Shipping builds must bake in the **exact** same value as Render.

Xcode Cloud **Environment** vars are available only during the **build** — they are **not** present on the user’s device. You must inject the secret into Info.plist at archive time via build-setting expansion:

`Config/Secrets.release.xcconfig` → `FITLOG_PROXY_SHARED_SECRET` build setting → `FitLog/Info.plist` value `$(FITLOG_PROXY_SHARED_SECRET)` (with `INFOPLIST_EXPAND_BUILD_SETTINGS=YES`).

Do **not** rely on `INFOPLIST_KEY_FITLOG_PROXY_SHARED_SECRET` — Xcode ignores custom/user-defined `INFOPLIST_KEY_*` keys, so the secret never reaches the binary (TestFlight then 401s against Render).

#### Local archive (Mac you control)

```bash
cp Config/Secrets.release.xcconfig.example Config/Secrets.release.xcconfig
# Edit Config/Secrets.release.xcconfig — set FITLOG_PROXY_SHARED_SECRET=<same as Render>
# File is gitignored; never commit it.
```

Then **Product → Archive** (Release).

#### Xcode Cloud (recommended for TestFlight)

Repo already includes `[ci_scripts/ci_pre_xcodebuild.sh](../ci_scripts/ci_pre_xcodebuild.sh)`. Xcode Cloud runs it before `xcodebuild`; the script writes gitignored `Config/Secrets.release.xcconfig` from the workflow secret.

**A. Add the Environment Variable in App Store Connect**

1. Open [App Store Connect](https://appstoreconnect.apple.com) → your app **Workout Log AI**.
2. **Xcode Cloud** (left sidebar) → select the workflow that archives / ships to TestFlight (often named after the scheme, e.g. **FitLog**).
3. Open the workflow → **Environment** (or **Edit Workflow** → **Environment**).
4. **+** Add Environment Variable:
  - **Name:** `FITLOG_PROXY_SHARED_SECRET` (must match exactly — the script and xcconfig use this name)
  - **Value:** the **same** string you set on Render
  - **Secret:** turn **ON** (hides value in logs/UI)
5. Scope: make it available to this workflow’s Archive / Release actions (if ASC offers per-action toggles, enable it for the archive/build action).
6. Save the workflow.

**B. Confirm the CI script is on the branch Xcode Cloud builds**

- Path must be `ci_scripts/ci_pre_xcodebuild.sh` at the **repo root** (same level as `FitLog.xcodeproj`).
- File must be **executable** (`chmod +x`) and committed.
- Script behavior:
  - If `FITLOG_PROXY_SHARED_SECRET` is set → writes `Config/Secrets.release.xcconfig`
  - If unset → **fails the build** (do not ship a binary that will 401)

**C. Start a new Xcode Cloud build**

Environment changes apply to **new** runs only. Start a build from Xcode Cloud (or push to the watched branch). In the build log, look for:

```text
Wrote Config/Secrets.release.xcconfig for Release Info.plist expansion
```

If the build fails with “FITLOG_PROXY_SHARED_SECRET is not set”, the ASC Environment Variable name/scope is wrong.

**D. Verify the TestFlight binary (do not log the secret)**

After the build is in TestFlight, confirm Premium AI works on device (Coach message succeeds). That is the real end-to-end check.

Optional local inspect of an `.ipa`/`.xcarchive` you exported: Info.plist key `FITLOG_PROXY_SHARED_SECRET` should be non-empty. Never paste the value into tickets, chat, or screenshots.

#### Common failures


| Symptom                                               | Cause                                                                        |
| ----------------------------------------------------- | ---------------------------------------------------------------------------- |
| TF Coach → 401 / unauthorized                         | Secret missing from archive, or ≠ Render                                     |
| `/health` authRequired true, Debug AI works, TF fails | Debug used scheme env; Cloud archive never got `Secrets.release.xcconfig`    |
| Script warning “not set”                              | ASC env var missing, wrong name, or Secret not attached to this workflow     |
| xcconfig parse issues                                 | Prefer a hex secret (`openssl rand -hex 32`) — avoid spaces/`#` in the value |


### 3. OpenAI hard monthly budget + alerts

1. [platform.openai.com](https://platform.openai.com) → prefer a **dedicated project/key** used only by this proxy.
2. Billing / Limits → set a **hard monthly budget**.
3. Enable email alerts at ~50% / 80% / 100% (or closest options).
4. Confirm Render’s `OPENAI_API_KEY` is that project’s key.

### 4. MuscleWiki quotas / alerts

1. Open MuscleWiki API / billing dashboard.
2. Note plan rate limits and any spend/quota caps; enable usage alerts if available.
3. Optionally set `ALLOW_FORM_GUIDE_STREAM=0` on Render for launch (see §1).

### 5. Prefer paid always-on Render

Free Render spins down → cold starts look like AI failure, and in-memory rate-limit buckets reset on wake.

For launch: use a paid instance that stays up. After ~15–30 minutes idle, confirm `/health` and a Coach message still respond quickly.

### 6. Without secret → **401** (or **503**)

```bash
# Should fail — no secret header
curl -i -X POST https://the-workout-log.onrender.com/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"hi"}],"max_tokens":16}'
```

- Secret set, wrong/missing header → **401** `Unauthorized`
- Secret required on server but unset → **503** misconfigured

Form guide without secret should also 401:

```bash
curl -i 'https://the-workout-log.onrender.com/v1/form-guide/search?q=bench&limit=1'
```

### 7. Burst chat → **429**; oversized body → **400**

Defaults: **10 chat / min / IP**, **100 / day / IP**.

```bash
SECRET='your-secret-here'
for i in $(seq 1 12); do
  echo -n "$i "
  curl -s -o /dev/null -w "%{http_code}\n" -X POST \
    https://the-workout-log.onrender.com/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "X-FitLog-Proxy-Secret: $SECRET" \
    -d '{"messages":[{"role":"user","content":"ping"}],"max_tokens":8}'
done
```

Expect mostly **200**, then **429** after the per-minute cap.

Oversized body (e.g. >24 messages) → **400**. Defaults: `MAX_CHAT_MESSAGES=24`, `MAX_CHAT_CHARS=40000`, `MAX_CHAT_TOKENS=2048`.

### 8. Release / TestFlight AI works **with** secret

1. Archive/upload a build that includes the matching secret (§2).
2. On a physical device (TestFlight):
  - Unlock Premium (sandbox purchase or RC promo).
  - Send a Coach message → success (not 401 / “couldn’t reach AI”).
  - Open an exercise form guide that hits the proxy → loads (or soft daily-limit copy, not auth failure).
3. If AI works in Debug (scheme env) but fails in TF → Release secret was not injected into the archive.

### Pass criteria (§2b)


| Check              | Pass                                     |
| ------------------ | ---------------------------------------- |
| `/health`          | `authRequired: true`                     |
| iOS Release secret | same value as Render, present in archive |
| OpenAI             | hard cap + alert emails on               |
| MuscleWiki         | quotas understood / alerts on            |
| Host               | always-on (not free sleep) for launch    |
| No secret          | 401 (or 503 if misconfigured)            |
| Burst              | 429                                      |
| TF Premium AI      | works with secret                        |


## 3. App Store Connect packaging

Copy sources: [APP_STORE_METADATA.md](../APP_STORE_METADATA.md), [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md), [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md), [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md).

Do this **after** a signed-off TestFlight build exists (§1) and proxy/IAP backends are ready (§2b + RevenueCat). Packaging does **not** replace a green device smoke test.

### Checklist

- [x] App name **Workout Log AI**; subtitle / keywords / description / What’s New  
- [x] Support URL + Privacy URL live (GitHub Pages `/docs`) and entered in App Information  
- [x] Subscription group attached to this version (first group ships with the version)  
- [x] ASC products not stuck on Missing Metadata (review screenshot + group localization)  
- [x] Privacy Nutrition Labels: Purchases + Health (sleep, HRV, RHR) + Photos + User ID + Other (AI workout text)  
- [ ] Screenshots: Home+readiness, paywall, Coach, History, widget (iPhone **and** iPad sizes)  
- [ ] Review notes + contact pasted (compliance doc § App Review notes)  
- [ ] RevenueCat Current offering `default` + products attached to `premium` (production `appl_` key)  
- [ ] Age rating + category + Paid Apps Agreement / tax / banking complete  

### 0. Prerequisites in App Store Connect

1. Open [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **Workout Log AI** (`com.acianfrocco.FitLog`).
2. Confirm **Paid Apps Agreement**, banking, and tax are **Active** (Account → Agreements, Tax, and Banking). Subscriptions cannot ship without this.
3. Confirm the app record **Name** is **Workout Log AI** (rename if the ASC record still says “The Workout Log”). Bundle ID must stay `com.acianfrocco.FitLog`.

### 1. App Information (URLs + category + rights)

**Path:** App → **App Information** (left sidebar under General).


| Field                | Value                                                      |
| -------------------- | ---------------------------------------------------------- |
| Name                 | Workout Log AI                                             |
| Privacy Policy URL   | `https://cianfrocco4.github.io/FitLog/privacy-policy.html` |
| License Agreement    | Apple Standard EULA (do not attach a custom EULA)          |
| Category (Primary)   | Health & Fitness                                           |
| Category (Secondary) | Optional — Lifestyle                                       |
| Content Rights       | See **§1a** below (required before Add for Review)         |


**Support URL**, **Copyright**, and most marketing fields are on the **version** page (App Store tab → iOS version):


| Field         | Value                                               |
| ------------- | --------------------------------------------------- |
| Support URL   | `https://cianfrocco4.github.io/FitLog/support.html` |
| Description   | Must include Terms of Use URL — [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) |
| Marketing URL | Optional (same site, GitHub, or leave blank)        |
| Copyright     | `2026 Anthony Cianfrocco` (see **§1b**)             |

#### 1a. Content Rights Information (blocks “Add for Review” if empty)

**Path:** App → **App Information** → **Content Rights** → **Set Up Content Rights Information** (or Edit).

Apple asks whether the app contains, shows, or accesses **third-party content**.

| Answer | When |
|--------|------|
| **Yes** — and confirm you have the necessary rights | **Use this** if Premium form guides show **MuscleWiki** videos/media (or other licensed third-party content). Your MuscleWiki API / commercial access is the rights basis. |
| **No** | Only if the shipping app never shows third-party licensed media (user-only workouts + your own UI). Do **not** pick No if MuscleWiki form content ships. |

Save. The “Unable to Add for Review → Content Rights Information” error clears after this is set.

#### 1b. Copyright (version page)

**Path:** App Store tab → your iOS version → scroll to **Copyright** (often near Description / What’s New).

| Field | Value |
|-------|--------|
| Copyright | `2026 Anthony Cianfrocco` |

Format is usually `Year Name` (© symbol optional; ASC often prepends it on the store). Update the year on later releases if you want.

#### 1c. Price (blocks “Add for Review” if empty)

**Path:** App → **Pricing and Availability** (sometimes under Monetization / Distribution).

1. **Price Schedule** / **App Store Price** → choose **Free** (`$0.00` / Tier 0).  
   The app is free to download; Premium is sold via IAP/subscriptions (already configured separately).
2. Confirm **Availability** includes the countries you want (default: all available).
3. Save.

Do **not** set a paid download price unless you intentionally want a paid app + IAP (unusual for this product).


**Verify pages (incognito):**

```bash
open https://cianfrocco4.github.io/FitLog/privacy-policy.html
open https://cianfrocco4.github.io/FitLog/support.html
```

Both must return **200** (not GitHub 404). Pages source: branch `main`, folder `/docs` (see [Enable GitHub Pages](#enable-github-pages) above).

### 2. Version metadata (subtitle, keywords, description, What’s New)

**Path:** App → **App Store** tab → select the **iOS version** you will submit (e.g. **1.0.1** Prepare for Submission). If 1.0 is already live / closed, create **1.0.1** first — Xcode Cloud cannot attach new binaries to a closed train.

Paste from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md):


| Field            | Limit     | Recommended                                                                                                                                                   |
| ---------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Subtitle         | 30        | `Train smarter. Recover better.`                                                                                                                              |
| Keywords         | 100 total | `gym,fitness,strength,readiness,HRV,sleep,AI,coach,hypertrophy,training,lifting,periodization` (no spaces after commas; don’t repeat words from the app name) |
| Promotional Text | 170       | Optional; can update without a new binary                                                                                                                     |
| Description      | 4000      | Full free/Premium/readiness/privacy blurb in metadata doc                                                                                                     |
| What’s New       | —         | Readiness, Premium AI, on-device coaching note, widget, trial, SIWA optional                                                                                  |


Primary language: **English (U.S.)**. Add other localizations only if you have translated screenshots + copy.

### 3. Age rating

**Path:** App Information → **Age Ratings** → Edit / Complete questionnaire.

Use answers from [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md):


| Topic                                 | Answer                                                       |
| ------------------------------------- | ------------------------------------------------------------ |
| Unrestricted web access               | No                                                           |
| User-generated content broadly shared | No                                                           |
| Made for Kids                         | No                                                           |
| Gambling                              | No                                                           |
| Violence / sexual / mature            | None                                                         |
| Medical/treatment info                | None (fitness logging / readiness only — not medical advice) |


**Expected rating:** 4+.

### 4. Privacy Nutrition Labels

Your answers appear on the App Store product page (“App Privacy”). They must match [docs/privacy-policy.html](privacy-policy.html), [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md), and real app + SDK behavior (including **RevenueCat**).

**Path:** App Store Connect → **Workout Log AI** → **App Privacy** (left sidebar) → **Get Started** (first time) or **Edit**.

Also see Apple’s guide: [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).

#### 4a. Tracking

Apple asks whether data from your app is used to **track** users (link with third-party data for ads/ad measurement, or share with a data broker).


| Question                                                                          | Answer | Why                                                                                                                 |
| --------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------- |
| Do you or your third-party partners use data from this app for tracking purposes? | **No** | No ATT prompt, no ad SDKs, no analytics/attribution SDKs. RevenueCat is used for subscription status, not tracking. |


Do **not** enable tracking just because you use Sign in with Apple or RevenueCat.

#### 4b. “Do you collect data from this app?”

Answer **Yes**.  
Then select **every** data type below (you will configure each type in the next screens).

**Select these data types** (checkboxes in the Data Types picker):


| Group in ASC         | Data type to check     | Collected by Workout Log AI?                                                            |
| -------------------- | ---------------------- | --------------------------------------------------------------------------------------- |
| **Health & Fitness** | **Fitness**            | Yes — workouts, sets, training load, readiness score inputs                             |
| **Health & Fitness** | **Health**             | Yes — optional HealthKit: sleep, HRV, resting HR; optional write of workouts/energy/HR  |
| **Purchases**        | **Purchase History**   | Yes — subscription / lifetime status via StoreKit + RevenueCat                          |
| **User Content**     | **Photos or Videos**   | Yes — optional progress photos (on device)                                              |
| **User Content**     | **Other User Content** | Yes — workout/exercise text sent to AI proxy when Premium user uses Coach / form guides |
| **Identifiers**      | **User ID**            | Yes — optional Sign in with Apple user identifier; RevenueCat App User ID               |
| **Contact Info**     | **Name**               | Yes (optional) — only if user shares name via Sign in with Apple                        |
| **Contact Info**     | **Email Address**      | Yes (optional) — only if user shares email via Sign in with Apple                       |


**Do not select** (for this app today): Location, Contacts, Precise/Coarse Location, Browsing History, Search History, Device ID / Advertising Data, Usage Data (product interaction analytics), Diagnostics (unless you add Crashlytics/Sentry later), Financial Info / Payment Info (Apple handles payments; you don’t collect card numbers), Sensitive Info, etc.

Click **Next** / continue after selecting types.

#### 4c. Configure each selected type (same pattern)

For **each** data type, ASC asks roughly:

1. **Is this data used for tracking?** → **No** (all types).
2. **Is this data linked to the user’s identity?** → see table below.
3. **Purpose(s)** → check **App Functionality** only (uncheck Advertising, Analytics, Product Personalization, Other unless true).


| Data type          | Linked to identity? | Purpose           | Notes for the form                                                                                                                                                               |
| ------------------ | ------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fitness            | **Yes**             | App Functionality | Workout logs, programs, history stored on device; used to run the app                                                                                                            |
| Health             | **Yes**             | App Functionality | Optional readiness reads (sleep, HRV, RHR); optional HealthKit workout sync write                                                                                                |
| Purchase History   | **Yes**             | App Functionality | Unlock Premium via Apple/RevenueCat; restore purchases                                                                                                                           |
| Photos or Videos   | **Yes**             | App Functionality | Optional progress photos stored locally                                                                                                                                          |
| Other User Content | **No**              | App Functionality | Exercise names / program structure / coach text sent to proxy → OpenAI / MuscleWiki when user invokes Premium AI. Privacy policy: not linked to Apple ID/email in those requests |
| User ID            | **Yes**             | App Functionality | SIWA identifier (optional); RevenueCat App User ID for entitlements / comps                                                                                                      |
| Name               | **Yes**             | App Functionality | Optional SIWA; stored on device for account display                                                                                                                              |
| Email Address      | **Yes**             | App Functionality | Optional SIWA; stored on device for account display                                                                                                                              |


**Why “Other User Content” is Not Linked:** proxy requests intentionally omit Apple ID / email / name. Workout text alone is not tied to an account identifier in those network calls. Keep this consistent with the privacy policy AI section.

**Why Health/Fitness/Purchases/User ID/Photos are Linked:** they are associated with the person using the app on that device / optional Apple account / subscription customer, even when stored primarily on-device. Apple’s definition of “linked” is broad — when in doubt for account- or device-bound personal data used for app features, choose **Linked**.

#### 4d. Third-party partners you must account for

Nutrition labels cover **your code + third-party SDKs**.


| Partner                                             | Declare via                                                                     |
| --------------------------------------------------- | ------------------------------------------------------------------------------- |
| **RevenueCat** (`purchases-ios`)                    | Purchase History + User ID (already in table)                                   |
| **OpenAI** (via your Render proxy)                  | Other User Content (AI prompts) — Not Linked                                    |
| **MuscleWiki** (via your Render proxy)              | Other User Content / form-guide related content — covered by Other User Content |
| **Apple** (Sign in with Apple, StoreKit, HealthKit) | Covered by Contact Info / User ID / Purchases / Health & Fitness as above       |


You do **not** declare “OpenAI collects data” as a separate tracking partner for ads. You declare that **your app** collects Other User Content for App Functionality (which may be processed by those services).

#### 4e. Publish / save

1. Finish every data-type questionnaire until App Privacy shows a complete summary.
2. Confirm the product-page preview style summary matches intent:
  - **Data Used to Track You** — none / not listed  
  - **Data Linked to You** — Health & Fitness, Purchases, Photos, Contact Info (if declared), Identifiers  
  - **Data Not Linked to You** — Other User Content (AI), if you set Linked = No
3. Click **Publish** / **Save** if ASC requires an explicit publish step (some accounts show “Publish” before the label goes live on the store page).
4. Re-open App Privacy after saving and spot-check — edits can leave a type incomplete.

#### 4f. Consistency checks (avoid Review rejection)


| Check                             | Must match                                                                                                                              |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Privacy Policy URL                | Live page describes Health, SIWA, Purchases, AI proxy, photos                                                                           |
| App Description                   | Includes Apple Standard EULA URL (`stdeula`)                                                                                            |
| In-app paywall / settings         | Restore + Terms of Use + Privacy Policy links (`SubscriptionStoreView` + More → Subscription + More → Legal & Support)                  |
| `PrivacyInfo.xcprivacy` in binary | Should not contradict (manifest declares collected types for required-reason APIs; nutrition labels are the store-facing questionnaire) |
| No “Data Not Collected”           | Do not claim you collect nothing while shipping HealthKit + IAP + optional AI                                                           |
| Tracking = No                     | Do not add IDFA/ad SDKs without updating this section                                                                                   |


#### 4g. What you are **not** declaring (and why)


| Type                         | Why omitted                                                                                              |
| ---------------------------- | -------------------------------------------------------------------------------------------------------- |
| Device ID / Advertising Data | No IDFA / ads                                                                                            |
| Usage Data / Analytics       | `AnalyticsService` is local OSLog only — not a third-party analytics product collecting for your servers |
| Diagnostics                  | No Crashlytics/Sentry in the shipping app today                                                          |
| Payment Info                 | Card/payment data stays with Apple                                                                       |
| Precise Location             | App does not request location                                                                            |


If you later add Firebase/Sentry/etc., return here and add Diagnostics / Usage Data as needed.

#### Pass criteria (§3.4)


| Check                        | Pass                                |
| ---------------------------- | ----------------------------------- |
| Tracking                     | **No**                              |
| Fitness + Health             | Linked, App Functionality           |
| Purchase History             | Linked, App Functionality           |
| Photos or Videos             | Linked, App Functionality           |
| Other User Content (AI)      | **Not** linked, App Functionality   |
| User ID                      | Linked, App Functionality           |
| Name + Email (optional SIWA) | Linked, App Functionality           |
| Summary saved/published      | Visible and complete in App Privacy |
| Matches privacy policy       | No contradictions                   |


### 5. Subscriptions + Missing Metadata (ASC)

**Path:** App → **Subscriptions** (Monetization).

1. Group: **Workout Log AI Premium** (create if missing).
2. Products (IDs must match code / RevenueCat — see [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)):
  - `workoutlogai_premium_monthly`
  - `workoutlogai_premium_annual`
  - Optional: `workoutlogai_premium_lifetime`
3. For **each** product / the group, clear **Missing Metadata**:
  - **App Store Localization** on the **subscription group** (display name) — easy to miss.
  - Localizations on each product (display name + description).
  - **Review Information → Screenshot** — see **§5a** below (this is the usual blocker).
  - Introductory offer: **14-day free** on monthly/annual if that is what you market in-app.
4. Subscription levels: prefer **annual higher** than monthly for upgrade/downgrade UX.
5. Open the **iOS version** → scroll to **In-App Purchases and Subscriptions** → **+** → attach the subscription group / products to **this version**. First subscription group **must** ship with a version.

Status must leave “Missing Metadata” before you can submit cleanly.

#### 5a. Review Information screenshot (clears “Missing Metadata”)

Apple requires **one review screenshot per auto-renewable subscription** (or per product that still shows Missing Metadata). It is **only for App Review** — it does **not** appear on the App Store product page (that’s §3.7 Previews and Screenshots).

**What to show:** StoreKit `SubscriptionStoreView` with Monthly / Annual **title, duration, and price** visible, plus Restore and Terms of Use / Privacy Policy. Do **not** upload a blank screen, “Plans unavailable” only, an App Store marketing collage, or a photo of your Mac desktop.

**Capture (Simulator — recommended)**

1. Run **Workout Log AI** on an iPhone simulator (e.g. iPhone 16 or 16 Pro Max). Prefer a build that can load StoreKit products (scheme StoreKit Configuration = `Configuration.storekit`, or TestFlight) so `SubscriptionStoreView` shows real plans — not the static fallback-only state.
2. Navigate: **More** → **Subscription** → **Upgrade to Premium**.
  - Alternate: trigger any Premium gate (Coach send, History 30/90 days, AI program) so `PaywallView` opens.
3. Wait until subscription title, length, and price render. Scroll so Terms of Use and Privacy Policy are visible if needed.
4. Capture:
  - Simulator menu → **Device → Trigger Screenshot**, or  
  - `xcrun simctl io booted screenshot ~/Desktop/workout-log-ai-paywall-review.png`
5. Confirm the PNG is phone-sized (typical: 1179×2556, 1290×2796, etc.). Specs: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications).

**Capture (physical device)**

1. Same navigation on a free (non-Premium) account.
2. Side button + Volume Up → screenshot → AirDrop / Photos → save PNG/JPEG to Mac.

**Upload in App Store Connect**

1. **Monetization** → **Subscriptions** → open group **Workout Log AI Premium**.
2. Open `**workoutlogai_premium_monthly**`.
3. Scroll to **Review Information** (near the bottom; sometimes under a collapsible section).
4. **Screenshot** → **Choose File** → select the paywall PNG.
5. Optional but useful: **Review Notes** on that product — e.g.
  `Paywall: More → Subscription → Upgrade to Premium. Sandbox Apple ID can purchase. Restore is on the paywall.`
6. **Save**.
7. Repeat for `**workoutlogai_premium_annual**` (and lifetime if you created it).
  - **Same screenshot file is fine** for every product in the group — Apple wants proof the subscription UI exists; you do not need a unique image per SKU.
8. Wait 1–5 minutes → refresh ASC. Product status should leave **Missing Metadata** (often → **Ready to Submit**).
9. In **RevenueCat**, refresh / re-sync products if the “Missing Metadata” warning still shows (RC mirrors ASC).

**If upload is rejected / won’t stick**


| Issue                               | Fix                                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------------------ |
| Wrong dimensions / too small        | Use a full-device simulator screenshot, not a cropped window grab                                |
| Paywall empty / “unavailable”       | Capture after offerings load; or use TestFlight with production RC key                           |
| Still Missing Metadata after upload | Also finish **group** App Store Localization + each product’s Display Name / Description / price |
| Uploaded on wrong product           | Open each SKU’s own Review Information section                                                   |
| Lifetime is non-consumable          | Upload under that IAP’s Review Information the same way                                          |


**Pass criteria (§5a):** every shipping subscription SKU has a Review Information screenshot; ASC status is not Missing Metadata; RC warning cleared after sync.

### 6. RevenueCat dashboard (pairs with ASC)

1. Confirm iOS app uses the **production** public SDK key (`appl_…` in shipping Info.plist).
2. Entitlement ID: `**premium**` (exact).
3. Offering identifier `**default**` marked **Current**.
4. Packages linked to the ASC product IDs above and attached to `premium`.
5. After a sandbox purchase on device: RC Customer shows the entitlement; after launch, confirm **production** transactions (post-release).

### 7. Screenshots

Required because the binary targets **iPhone and iPad** (`TARGETED_DEVICE_FAMILY = 1,2`).

**Path:** App Store tab → version → **Previews and Screenshots**.


| ASC slot     | Capture device (Simulator OK)                  |
| ------------ | ---------------------------------------------- |
| 6.7" Display | iPhone 16 Pro Max (or current 6.7" equivalent) |
| 6.1" Display | iPhone 16 (or current 6.1" equivalent)         |
| 13" Display  | iPad Pro 13-inch                               |


**Shots to capture (same set for each required size):**

1. **Home + readiness** — today’s score / Connect Health CTA visible
2. **Paywall** — plans + Restore + legal links visible
3. **Coach** — Premium chat (sandbox Premium or promo)
4. **History** — sessions list (free 14-day range is fine)
5. **Widget** — Home Screen with readiness / quick-log widget

Tips: use Release or TestFlight UI (not DEBUG paywall “Configure RevenueCat” text); light or dark is fine if readable; no status-bar secrets. Specs: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications).

Optional: App Preview videos — not required for v1.

### 8. App Review Information

**Path:** version page → **App Review Information**.

1. Paste **Review Notes** from [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md) (SIWA optional, **Delete Account** path, free offline logging, restore + App User ID comp path, no demo account).
2. Contact: First **Anthony**, Last **Cianfrocco**, phone (your number), email `acianfrocco@gmail.com` (or your support address).
3. **Sign-in required?** No — reviewers can tap **Continue without signing in**. To review **account deletion**, they must Sign in with Apple, then More → Delete Account (see [APP_REVIEW_RESOLUTION.md](APP_REVIEW_RESOLUTION.md)).
4. Attach the physical-device **Delete Account** screen recording in Resolution Center and in Notes when resubmitting after a 5.1.1(v) rejection.

### 9. Build selection (on the version)

1. **Build** → **+** → choose the TestFlight build you signed off in §1 (same binary that passed smoke + Premium AI with proxy secret).
2. If the build is missing: wait for processing, or confirm export compliance was answered on upload (`ITSAppUsesNonExemptEncryption = false` → exempt / standard HTTPS).
3. Do **not** submit an older build that lacks §2b secret injection or the production-risk fixes.

### Pass criteria (§3)


| Check           | Pass                                                               |
| --------------- | ------------------------------------------------------------------ |
| Name + metadata | Workout Log AI; subtitle/keywords/description/What’s New filled    |
| Copyright       | Set on version (e.g. `2026 Anthony Cianfrocco`)                    |
| Content Rights  | Declared under App Information                                     |
| Price           | App set to **Free** under Pricing and Availability                 |
| URLs            | Privacy + Support open in browser; entered in ASC                  |
| Privacy labels  | Tracking No; Health, Purchases, Photos, User ID, Other/AI declared |
| IAP             | Group attached to version; no Missing Metadata                     |
| RevenueCat      | Current `default` + `premium` entitlement                          |
| Screenshots     | 6.9" (Pro Max) + iPad 13"; optional 6.3"                           |
| Review notes    | Pasted; contact complete                                           |
| Build           | Signed-off TF build selected on the version                        |


When all rows pass → continue to [§4 Submit](#4-submit).

## 4. Submit

- [ ] Select the signed-off TestFlight build  
- [ ] Attach IAPs  
- [ ] Submit for Review  

## 5. Post-release (48h)

- [ ] Production purchase → Premium Active → Coach / Adjust unlock  
- [ ] RevenueCat shows **production** transactions  
- [ ] Existing users migrate cleanly (V5→V6)  
- [ ] Crash / feedback watch (esp. non–Apple Intelligence devices)  
- [ ] OpenAI / MuscleWiki spend vs Premium MAU (daily for first 2 weeks)  

## Related

- [PHASE_2_STAGE_A_OPERATOR.md](PHASE_2_STAGE_A_OPERATOR.md)  
- [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md)  
- [ON_DEVICE_AI.md](ON_DEVICE_AI.md)  
- [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)

