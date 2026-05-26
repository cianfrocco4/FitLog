# Staging backend (feature branch)

This branch points the iOS app at the **Render Testing** web service instead of production.

| Environment | Render service | Base URL |
|-------------|----------------|----------|
| **Testing (this branch)** | The Workout Log - Testing | `https://the-workout-log-testing.onrender.com` |
| **Production (`main`)** | the-workout-log | `https://the-workout-log.onrender.com` |

Configured in [`FitLog/Info.plist`](FitLog/Info.plist) via `FITLOG_AI_BASE_URL` and `FITLOG_FORM_GUIDE_BASE_URL`.

## Render setup (Testing service)

- **Branch:** feature branch (e.g. `feature/dynamic-periodized-programs`)
- **Root Directory:** `backend`
- **Environment:** `OPENAI_API_KEY`, `MUSCLEWIKI_API_KEY`

Verify:

```bash
curl https://the-workout-log-testing.onrender.com/health
```

Expect `"formGuide": true` when MuscleWiki is configured.

## Pre-merge checklist (before merging into `main`)

1. Revert [`FitLog/Info.plist`](FitLog/Info.plist):
   - `FITLOG_AI_BASE_URL` → `https://the-workout-log.onrender.com`
   - `FITLOG_FORM_GUIDE_BASE_URL` → `https://the-workout-log.onrender.com`
2. Remove FUTURE/TODO comments from Info.plist, `OpenAIConfig.swift`, and `MuscleWikiConfig.swift`
3. Delete this file (`STAGING_BACKEND.md`)
4. Confirm production Render is deployed from `main` with latest backend
5. `curl https://the-workout-log.onrender.com/health` — production healthy

See also [`OPENAI_SETUP.md`](OPENAI_SETUP.md) and [`FORM_GUIDE_SETUP.md`](FORM_GUIDE_SETUP.md) for production configuration.
