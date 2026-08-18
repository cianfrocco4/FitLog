# Form guide (MuscleWiki) setup

FitLog loads exercise demonstration videos and steps from the **MuscleWiki API** for the form guide feature (compact previews, full sheet, library thumbnails).

## Production (recommended): backend proxy

Your Render server holds the MuscleWiki key; the app only talks to your proxy URL.

1. **Render environment**  
   Add `MUSCLEWIKI_API_KEY` = your MuscleWiki key (`mw_…`) on the same service as `OPENAI_API_KEY`.

2. **App configuration**  
   Set the proxy base URL (no trailing slash) in one of:
   - **Info.plist:** `FITLOG_FORM_GUIDE_BASE_URL` = `https://the-workout-log.onrender.com`
   - **Xcode scheme:** Run → Arguments → Environment Variables → `FITLOG_FORM_GUIDE_BASE_URL`

3. **Leave the app key empty**  
   Keep `MUSCLEWIKI_API_KEY` empty in Info.plist when using the proxy.

**Priority:** If `FITLOG_FORM_GUIDE_BASE_URL` is set, the app uses the proxy and **ignores** `MUSCLEWIKI_API_KEY`.

The app calls:

- `{FITLOG_FORM_GUIDE_BASE_URL}/v1/form-guide/search?...`
- `{FITLOG_FORM_GUIDE_BASE_URL}/v1/form-guide/exercises/:id`
- `{FITLOG_FORM_GUIDE_BASE_URL}/v1/form-guide/stream/videos/branded/:filename`

See **backend/README.md** for server route details.

---

## Development: direct API key (optional)

For local work without the proxy:

1. Xcode → **Product → Scheme → Edit Scheme… → Run → Environment Variables**
2. Add `MUSCLEWIKI_API_KEY` = your key
3. **Remove or clear** `FITLOG_FORM_GUIDE_BASE_URL` from the scheme so direct mode is used

Or set `MUSCLEWIKI_API_KEY` in Info.plist locally (do not commit the real key).

---

## Getting a MuscleWiki API key

1. Sign up at [api.musclewiki.com](https://api.musclewiki.com)
2. Open the Developer Dashboard and create an API key
3. Save the key immediately — it is often shown only once
4. Direct API access from your own code typically requires a paid tier (e.g. TESTING); see MuscleWiki’s current plans

Verify:

```bash
curl --request GET \
  --url 'https://api.musclewiki.com/exercises/1' \
  --header 'X-API-Key: YOUR_API_KEY'
```

---

## Verify in the app

1. Ensure `FITLOG_FORM_GUIDE_BASE_URL` points at your deployed backend
2. Redeploy Render after adding `MUSCLEWIKI_API_KEY`
3. Open **Barbell Bench Press** in the exercise library
4. You should see a form guide thumbnail and video preview

If videos fail with “not configured”, check Render logs and confirm `/health` returns `"formGuide": true`.

If the player is a **black or blank screen**:

1. Confirm the TestFlight/App Store binary includes the form-guide **download-then-play** path (`FormGuideVideoClipStore`). AVPlayer does **not** reliably send `X-FitLog-Proxy-Secret` on media requests, so streaming the proxy URL directly gets **401 JSON** and a black frame.
2. Confirm the iOS `FITLOG_PROXY_SHARED_SECRET` matches Render (`/health` reports `"authRequired": true`).

---

## Files

- `FitLog/Features/FormGuide/MuscleWikiConfig.swift` — reads `FITLOG_FORM_GUIDE_BASE_URL` and `MUSCLEWIKI_API_KEY`
- `FitLog/Features/FormGuide/ExerciseFormGuideService.swift` — proxy-aware networking
- `FitLog/Features/FormGuide/FormGuideVideoClipStore.swift` — authenticated URLSession download + on-disk playback
- `backend/server.js` — MuscleWiki proxy routes

## Security note

A MuscleWiki key embedded in the app binary can be extracted. Prefer the proxy for TestFlight and App Store builds. Rotate any key that was committed to git.
