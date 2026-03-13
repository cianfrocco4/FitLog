# OpenAI setup

FitLog uses **OpenAI’s Chat Completions API** with **gpt-4o-mini** for:

- **Form tips** on exercise detail (ExerciseDetailView)
- **Workout suggestions** on workout plans (WorkoutPlanView)

## API key (development)

For local development, set the key in one of these ways (checked in order):

1. **Environment variable**  
   Xcode → **Product → Scheme → Edit Scheme… → Run → Arguments** → **Environment Variables**. Add:
   - Name: `OPENAI_API_KEY`
   - Value: your key (e.g. `sk-…`)

2. **Info.plist**  
   The project already has an `OPENAI_API_KEY` entry in `FitLog/Info.plist`. Leave it empty in the repo; for release builds, fill in your key (see below).

If no key is set, the app falls back to built-in heuristic tips/suggestions (no network calls).

---

## Option 1: Backend proxy (recommended for production)

Your server holds the OpenAI key; the app only talks to your server. No key in the app.

1. **Deploy the proxy**  
   Use the `backend/` folder in this repo. See **backend/README.md** for:
   - Running locally (Node 18+, `OPENAI_API_KEY` env var).
   - Deploying to **Railway**, **Render**, or **Fly.io** (set `OPENAI_API_KEY` in the host’s environment).
2. **Point the app at your server**  
   Set the proxy base URL (no trailing slash) in one of these ways:
   - **Environment variable:** In the Xcode scheme, add `FITLOG_AI_BASE_URL` = `https://the-workout-log.onrender.com`
   - **Info.plist:** Set the `FITLOG_AI_BASE_URL` entry in `FitLog/Info.plist` to `https://the-workout-log.onrender.com` (e.g. for TestFlight/App Store).
3. **Leave the app key empty** when using the proxy. The app will call `{FITLOG_AI_BASE_URL}/v1/chat/completions` and the proxy will add the key and forward to OpenAI.

**Priority:** If `FITLOG_AI_BASE_URL` is set, the app uses the proxy (and ignores `OPENAI_API_KEY`). Otherwise it uses `OPENAI_API_KEY` and talks to OpenAI directly.

---

## Option 3: Deployment with key in the app (TestFlight / App Store)

To have **all users** use the same API key (you pay for usage):

1. **Add your key to Info.plist for release only**  
   - Open `FitLog/Info.plist` in Xcode.  
   - Find the `OPENAI_API_KEY` entry (already present; value is empty).  
   - Set the **Value** to your OpenAI API key (e.g. `sk-…`).  
   - Build and archive; the key is embedded in the app.

2. **Keep the key out of version control**  
   - **Option A:** Do **not** commit the line that contains your real key. Before each commit that touches Info.plist, clear the key back to empty, commit, then re-add the key locally for your next build.  
   - **Option B:** Add `FitLog/Info.plist` to `.gitignore` and maintain a template `Info.plist.example` (with empty `OPENAI_API_KEY`). Each developer / CI restores or generates Info.plist from the example and injects the key.  
   - **Option C:** Use a **Run Script** build phase that writes `OPENAI_API_KEY` into the built app’s Info.plist from an environment variable or a local file that is in `.gitignore` (e.g. `Secrets.xcconfig` or `secrets.plist`), so the key never appears in the committed Info.plist.

**Security note:** The key is inside the app binary and can be extracted by determined users. Set **usage limits and billing alerts** in your [OpenAI account](https://platform.openai.com/account/limits) so abuse is limited. For higher security or to avoid shipping a key, use a backend proxy (see earlier discussion) or user-provided keys in Settings.

**Getting 401 "Incorrect api key provided"?**
- **Trim spaces/newlines:** The app trims the key automatically; if you pasted into a plist, ensure there’s no extra space or newline after the key.
- **Verify the key:** At [platform.openai.com](https://platform.openai.com) go to API keys and confirm the key is valid and not revoked. Create a new key if needed.
- **Correct key type:** Use an API key from the OpenAI platform (Chat Completions / API usage), not a different product key.

## Switching the model

- **App (direct OpenAI or when proxy forwards client choice):** Set `FITLOG_AI_MODEL` in the Xcode scheme (Environment Variables) or in Info.plist. Examples: `gpt-4o-mini`, `gpt-5-mini`. Default if unset: `gpt-4o-mini`.
- **Proxy (Render/Railway/etc.):** Set the `OPENAI_MODEL` environment variable on the host (e.g. `gpt-5-mini`). Default: `gpt-4o-mini`. See **backend/README.md**.
- **Usage:** Form tips and suggestions are cached per exercise/workout, so repeated views don’t call the API again in the same session.

## Files

- `FitLog/OpenAIConfig.swift` – reads `OPENAI_API_KEY` and `FITLOG_AI_BASE_URL` from env or Info.plist.
- `FitLog/AIService.swift` – uses proxy URL when set, otherwise OpenAI with key.
- `backend/` – optional Node proxy (see **backend/README.md**).
