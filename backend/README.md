# FitLog backend proxy

Small backend that forwards FitLog’s **OpenAI** and **MuscleWiki form guide** requests using **your** API keys. Keys stay on the server; the app only talks to this URL.

**Requires:** Node 18+ (for `fetch`).

**Environment variables:**

| Variable            | Required                         | Default       | Description                         |
|---------------------|----------------------------------|---------------|-------------------------------------|
| `OPENAI_API_KEY`    | Yes (for chat)                   | —             | Your OpenAI API key                 |
| `OPENAI_MODEL`      | No                               | `gpt-4o-mini` | Model ID (e.g. `gpt-5-mini`)        |
| `MUSCLEWIKI_API_KEY`| Yes (for form guide routes)      | —             | Your MuscleWiki API key (`mw_…`)    |

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
3. In the service: **Variables** → add `OPENAI_API_KEY` and `MUSCLEWIKI_API_KEY`.
4. Deploy. Note the public URL (e.g. `https://your-app.up.railway.app`). No extra config needed; Railway runs `npm start` by default if you have a `package.json` in the deploy root.

### Render

1. [render.com](https://render.com) → New → Web Service.
2. Connect repo, set **Root Directory** to `backend`.
3. **Build command:** (leave empty or `npm install`)  
   **Start command:** `npm start`
4. **Environment** → add `OPENAI_API_KEY` and `MUSCLEWIKI_API_KEY`.
5. Deploy. Use the service URL as the base URL in the app (e.g. `https://the-workout-log.onrender.com`).

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

Proxies MuscleWiki with the server’s `MUSCLEWIKI_API_KEY`. No client auth required.

| Proxy route | Upstream |
|-------------|----------|
| `GET /v1/form-guide/search?q=&limit=` | `GET https://api.musclewiki.com/search?...` |
| `GET /v1/form-guide/exercises/:id` | `GET https://api.musclewiki.com/exercises/:id` |
| `GET /v1/form-guide/stream/videos/branded/:filename` | `GET https://api.musclewiki.com/stream/videos/branded/:filename` |

Video stream route forwards `Range` headers for AVPlayer seeking.

Returns **503** if `MUSCLEWIKI_API_KEY` is not set on the server.

Set `FITLOG_FORM_GUIDE_BASE_URL` in the iOS app to this service URL (can be the same host as `FITLOG_AI_BASE_URL`).

No auth required from the client (the server’s keys are used). For production you can add API keys or rate limiting later.

See **FORM_GUIDE_SETUP.md** in the repo root for iOS configuration.
