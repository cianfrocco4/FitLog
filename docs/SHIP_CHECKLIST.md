# Ship checklist — Workout Log AI (Phase 1 + 2)

Branch: `feature/phase-1-workout-log-ai` → merge to `main` before / with submission so GitHub Pages (`docs/`) stays aligned.

## 1. Xcode Cloud → TestFlight

- [ ] Xcode Cloud built **`feature/phase-1-workout-log-ai`** successfully  
- [ ] Install **that** TestFlight build on a physical device  
- [ ] Spot-check ([APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md)): free log + readiness + history clamp + Coach paywall; Premium unlock + Restore; widget  

| Build number | Date | Tester | Pass? |
|--------------|------|--------|-------|
| | | | |

## 2. Merge to `main`

- [x] Feature branch contains Phase 1 freemium + Phase 2 on-device AI  
- [x] Merged `feature/phase-1-workout-log-ai` → `main` (`fdd1a61`)  
- [x] `main` pushed  
- [x] **GitHub Pages** enabled (verified live 2026-07-26; see [Enable GitHub Pages](#enable-github-pages) below)  

## Enable GitHub Pages

The HTML files already live on `main` under `docs/privacy-policy.html` and `docs/support.html`. A **404** means Pages is off or pointed at the wrong branch/folder — not that the files are missing from git.

### Click path

1. Open the repo: [https://github.com/cianfrocco4/FitLog](https://github.com/cianfrocco4/FitLog)
2. Click **Settings** (repo toolbar; you need admin on the repo).
3. Left sidebar → **Pages** (under “Code and automation”).
4. Under **Build and deployment** → **Source**, choose **Deploy from a branch** (not “GitHub Actions” unless you already have a Pages workflow).
5. **Branch** row:
   - Branch: **`main`**
   - Folder: **`/docs`** (not `/ (root)`)
6. Click **Save**.
7. Wait 1–3 minutes. The Pages settings page should show something like:  
   **Your site is live at** `https://cianfrocco4.github.io/FitLog/`
8. Open these URLs (hard-refresh if you still see 404):
   - Privacy: https://cianfrocco4.github.io/FitLog/privacy-policy.html  
   - Support: https://cianfrocco4.github.io/FitLog/support.html  

### Why the path looks like that

| Setting | Effect |
|--------|--------|
| Branch `main` | Publishes whatever is on `main` |
| Folder `/docs` | Site root = contents of the `docs/` directory |
| File `docs/privacy-policy.html` | Public URL = `…/FitLog/privacy-policy.html` |

If you picked folder **`/ (root)`** by mistake, the URL would be  
`https://cianfrocco4.github.io/FitLog/docs/privacy-policy.html` instead — don’t use that for App Store Connect; switch Source folder back to **`/docs`**.

### After it’s live — App Store Connect

App Store Connect → your app → **App Information**:

- **Privacy Policy URL:** `https://cianfrocco4.github.io/FitLog/privacy-policy.html`
- **Support URL:** `https://cianfrocco4.github.io/FitLog/support.html`

(Also used on the paywall / legal links in the app.)

### If it still 404s

| Check | What to do |
|-------|------------|
| Wrong account/repo | Confirm you’re on **cianfrocco4/FitLog**, not a fork without Pages |
| Deploy not finished | Settings → Pages → look for a green “live” note; wait and retry |
| Files not on `main` | On GitHub, open `main` → `docs/` → confirm both `.html` files exist |
| Private repo | Free GitHub only allows Pages on public repos (or use GitHub Pro). Make the repo public, or host the two HTML files elsewhere |
| Cached 404 | Try a private/incognito window or append `?v=2` once |
| Actions failed | If Source is “GitHub Actions”, either fix that workflow or switch back to **Deploy from a branch** |

## 2b. API cost / proxy (before public launch)

Hardened proxy code lives in [`backend/server.js`](../backend/server.js). App production base URL: `https://the-workout-log.onrender.com` (`FitLog/Info.plist` → `FITLOG_AI_BASE_URL` / `FITLOG_FORM_GUIDE_BASE_URL`). Deploy the latest `backend/` to Render **before** verifying secrets.

Also see [BUILD_CONFIG_VERIFICATION.md](BUILD_CONFIG_VERIFICATION.md), [backend/README.md](../backend/README.md), [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md) §7.

### Checklist

- [ ] Deploy hardened `backend/` to Render (root directory `backend`)  
- [ ] Render `/health` shows `"authRequired": true`  
- [ ] `FITLOG_PROXY_SHARED_SECRET` matches Release archive (`Config/Secrets.release.xcconfig` or Xcode Cloud secret)  
- [ ] OpenAI project hard monthly budget + email alerts (~50% / 80% / 100%)  
- [ ] MuscleWiki plan quotas / alerts confirmed  
- [ ] Prefer paid always-on Render (or equivalent) — avoid free sleep for launch  
- [ ] Hit proxy **without** secret → **401** (or **503** if secret required but missing)  
- [ ] Burst chat → **429**; oversized body → **400**  
- [ ] Release/TestFlight AI Coach + form guide still work **with** secret  

### 0. Deploy the hardened backend

1. Push the branch that contains the updated `backend/server.js`.
2. Render → Web Service → **Root Directory** = `backend` → redeploy.
3. Confirm the service is healthy after deploy (next step).

### 1. Render env + `/health` → `"authRequired": true`

Render → service → **Environment** — set at least:

| Variable | Value |
|----------|--------|
| `OPENAI_API_KEY` | OpenAI key for this proxy only |
| `MUSCLEWIKI_API_KEY` | MuscleWiki key (`mw_…`) |
| `FITLOG_PROXY_SHARED_SECRET` | Long random secret (e.g. `openssl rand -hex 32`) |
| `REQUIRE_PROXY_SECRET` | `1` (recommended — fail closed even if `NODE_ENV` isn’t production) |
| `NODE_ENV` | `production` (if Render doesn’t already set it) |

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

Xcode Cloud **Environment** vars are available only during the **build** — they are **not** present on the user’s device. You must inject the secret into Info.plist at archive time (via `Config/Secrets.release.xcconfig` → [`Config/Release.xcconfig`](../Config/Release.xcconfig) → `INFOPLIST_KEY_FITLOG_PROXY_SHARED_SECRET`).

#### Local archive (Mac you control)

```bash
cp Config/Secrets.release.xcconfig.example Config/Secrets.release.xcconfig
# Edit Config/Secrets.release.xcconfig — set FITLOG_PROXY_SHARED_SECRET=<same as Render>
# File is gitignored; never commit it.
```

Then **Product → Archive** (Release).

#### Xcode Cloud (recommended for TestFlight)

Repo already includes [`ci_scripts/ci_pre_xcodebuild.sh`](../ci_scripts/ci_pre_xcodebuild.sh). Xcode Cloud runs it before `xcodebuild`; the script writes gitignored `Config/Secrets.release.xcconfig` from the workflow secret.

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
  - If unset → prints a warning and continues (archive succeeds but Premium AI will **401**)

**C. Start a new Xcode Cloud build**

Environment changes apply to **new** runs only. Start a build from Xcode Cloud (or push to the watched branch). In the build log, look for:

```text
Wrote Config/Secrets.release.xcconfig for Release Info.plist injection
```

If you only see the “not set” warning, the ASC Environment Variable name/scope is wrong.

**D. Verify the TestFlight binary (do not log the secret)**

After the build is in TestFlight, confirm Premium AI works on device (Coach message succeeds). That is the real end-to-end check.

Optional local inspect of an `.ipa`/`.xcarchive` you exported: Info.plist key `FITLOG_PROXY_SHARED_SECRET` should be non-empty. Never paste the value into tickets, chat, or screenshots.

#### Common failures

| Symptom | Cause |
|---------|--------|
| TF Coach → 401 / unauthorized | Secret missing from archive, or ≠ Render |
| `/health` authRequired true, Debug AI works, TF fails | Debug used scheme env; Cloud archive never got `Secrets.release.xcconfig` |
| Script warning “not set” | ASC env var missing, wrong name, or Secret not attached to this workflow |
| xcconfig parse issues | Prefer a hex secret (`openssl rand -hex 32`) — avoid spaces/`#` in the value |

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

| Check | Pass |
|-------|------|
| `/health` | `authRequired: true` |
| iOS Release secret | same value as Render, present in archive |
| OpenAI | hard cap + alert emails on |
| MuscleWiki | quotas understood / alerts on |
| Host | always-on (not free sleep) for launch |
| No secret | 401 (or 503 if misconfigured) |
| Burst | 429 |
| TF Premium AI | works with secret |

## 3. App Store Connect packaging

Copy from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) and [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md).

- [ ] App name **Workout Log AI**; subtitle / keywords / description / What’s New  
- [ ] Support URL + Privacy URL live (GitHub Pages `/docs`)  
- [ ] Subscription group attached to this version (first group ships with the version)  
- [ ] ASC products not stuck on Missing Metadata (review screenshot + group localization)  
- [ ] Privacy Nutrition Labels: Purchases + Health (sleep, HRV, RHR) + Photos + User ID + Other (AI workout text) as in [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)  
- [ ] Screenshots: Home+readiness, paywall, Coach, History, widget  
- [ ] Review notes pasted (see compliance doc § App Review notes)  
- [ ] RevenueCat Current offering `default` + products attached to `premium` (production `appl_` key)  

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
