# FitLog backend proxy

Small backend that forwards FitLog’s **OpenAI** and **MuscleWiki form guide** requests using **your** API keys. Keys stay on the server; the app only talks to this URL.

**Requires:** Node 18+ (for `fetch`).

**Environment variables:**

| Variable            | Required                         | Default       | Description                         |
|---------------------|----------------------------------|---------------|-------------------------------------|
| `OPENAI_API_KEY`    | Yes (for chat)                   | —             | Your OpenAI API key                 |
| `OPENAI_MODEL`      | No                               | `gpt-4o-mini` | Model ID (e.g. `gpt-5-mini`)        |
| `MUSCLEWIKI_API_KEY`| Yes (for form guide routes)      | —             | Your MuscleWiki API key (`mw_…`)    |
| `FITLOG_PROXY_SHARED_SECRET` | **Required in production** | — | Shared secret the iOS app sends as `X-FitLog-Proxy-Secret` |
| `REQUIRE_PROXY_SECRET` | No                            | —             | Set `1` to require secret even outside `NODE_ENV=production` |
| `CHAT_RATE_LIMIT_PER_MIN` / `_PER_DAY` | No | `10` / `100` | Per-IP chat limits |
| `FORM_GUIDE_RATE_LIMIT_PER_MIN` / `_PER_DAY` | No | `30` / `300` | Per-IP form-guide JSON limits |
| `FORM_GUIDE_STREAM_RATE_LIMIT_PER_MIN` | No | `300` | Per-IP video Range-request limit (separate from JSON) |
| `MAX_CHAT_TOKENS` / `MAX_CHAT_MESSAGES` / `MAX_CHAT_CHARS` | No | `2048` / `24` / `40000` | Chat body caps |
| `ALLOW_FORM_GUIDE_STREAM` | No | enabled | Set `0` to disable branded video proxy |

Chat completions cap `max_tokens` at **2048** per request by default. In production (`NODE_ENV=production` or `REQUIRE_PROXY_SECRET=1`), requests fail with **503** if `FITLOG_PROXY_SHARED_SECRET` is unset.

### Cost controls (launch checklist)

1. Set `FITLOG_PROXY_SHARED_SECRET` on the host and in the iOS Release archive.
2. Set OpenAI project **hard monthly budget** + email alerts (50% / 80% / 100%).
3. Confirm MuscleWiki plan quotas / alerts.
4. Prefer a paid always-on host so cold starts and emptied in-memory rate buckets do not look like outages.
5. Verify: no secret → **401** (or **503** if secret required but missing); burst chat → **429**.

## Run locally

```bash
cd backend
export OPENAI_API_KEY=sk-your-key-here
export MUSCLEWIKI_API_KEY=mw-your-key-here
npm start
```

Server listens on port 3000. The app will call `http://localhost:3000` only when using the Simulator against your machine (see iOS setup below); for a real device or TestFlight use a deployed URL.

## Deploy (pick one)

### Railway

1. [railway.app](https://railway.app) → New Project → Deploy from GitHub (or “Empty project” and connect repo).
2. Add a service: **Deploy from GitHub** → select your repo, set **Root Directory** to `backend` (or push only the backend folder).
3. In the service: **Variables** → add `OPENAI_API_KEY`, `MUSCLEWIKI_API_KEY`, and `FITLOG_PROXY_SHARED_SECRET`.
4. Deploy. Note the public URL (e.g. `https://your-app.up.railway.app`). No extra config needed; Railway runs `npm start` by default if you have a `package.json` in the deploy root.
5. Set the same `FITLOG_PROXY_SHARED_SECRET` value in the iOS app (`Info.plist` key `FITLOG_PROXY_SHARED_SECRET` or Xcode scheme env).

### Render

1. [render.com](https://render.com) → New → Web Service.
2. Connect repo, set **Root Directory** to `backend`.
3. **Build command:** (leave empty or `npm install`)  
   **Start command:** `npm start`
4. **Environment** → add `OPENAI_API_KEY`, `MUSCLEWIKI_API_KEY`, and `FITLOG_PROXY_SHARED_SECRET`.
5. Deploy. Use the service URL as the base URL in the app (e.g. `https://the-workout-log.onrender.com`).
6. Mirror `FITLOG_PROXY_SHARED_SECRET` in the iOS app configuration.

### Fly.io

```bash
cd backend
fly launch
# set OPENAI_API_KEY when prompted or: fly secrets set OPENAI_API_KEY=sk-...
fly secrets set MUSCLEWIKI_API_KEY=mw-...
fly deploy
```

Use `https://your-app-name.fly.dev` as the base URL.

---

## API

### Health

- **GET** `/health` — returns `{"ok":true,"service":"fitlog-proxy","formGuide":true}`. Does **not** call OpenAI or MuscleWiki. The iOS app pings this on launch when using proxy base URLs so hosts that sleep after idle (e.g. Render free tier) start warming up before the user needs AI or form guide features.

### OpenAI (Chat Completions)

Single forwarding endpoint, same shape as OpenAI Chat Completions:

- **POST** `/v1/chat/completions`
- **Body:** `{ "messages": [{"role":"system","content":"..."},{"role":"user","content":"..."}], "max_tokens": 500 }`
- **Response:** Same as [OpenAI Chat Completions](https://platform.openai.com/docs/api-reference/chat/create). The server forces `model` from `OPENAI_MODEL` and adds the API key.

Set `FITLOG_AI_BASE_URL` in the iOS app to this service URL.

### MuscleWiki (Form guide)

Proxies MuscleWiki with the server’s `MUSCLEWIKI_API_KEY`. When `FITLOG_PROXY_SHARED_SECRET` is set, clients must send header `X-FitLog-Proxy-Secret`.

| Proxy route | Upstream |
|-------------|----------|
| `GET /v1/form-guide/search?q=&limit=` | `GET https://api.musclewiki.com/search?...` |
| `GET /v1/form-guide/exercises/:id` | `GET https://api.musclewiki.com/exercises/:id` |
| `GET /v1/form-guide/stream/videos/branded/:filename` | `GET https://api.musclewiki.com/stream/videos/branded/:filename` |

Video stream route forwards `Range` headers for AVPlayer seeking.

Returns **503** if `MUSCLEWIKI_API_KEY` is not set on the server.

Set `FITLOG_FORM_GUIDE_BASE_URL` in the iOS app to this service URL (can be the same host as `FITLOG_AI_BASE_URL`).

When `FITLOG_PROXY_SHARED_SECRET` is configured on the server, set the same value in the iOS app (`FITLOG_PROXY_SHARED_SECRET`). Requests without the header are rejected with **401**, including branded video streams (missing this header is a blank/black AVPlayer). Default rate limits: **10** chat / **30** form-guide JSON requests per IP per minute, plus daily caps (**100** / **300**). Video `Range` requests use a separate budget (default **300**/min). Oversized chat bodies return **400**.

See **FORM_GUIDE_SETUP.md** in the repo root for iOS configuration.
