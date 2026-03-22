# FitLog AI proxy (Option 1)

Small backend that forwards FitLog’s AI requests to OpenAI using **your** API key. The key stays on the server; the app only talks to this URL.

**Requires:** Node 18+ (for `fetch`).

**Environment variables:**

| Variable         | Required | Default      | Description                    |
|------------------|----------|--------------|--------------------------------|
| `OPENAI_API_KEY` | Yes      | —            | Your OpenAI API key            |
| `OPENAI_MODEL`   | No       | `gpt-4o-mini`| Model ID (e.g. `gpt-5-mini`)   |

## Run locally

```bash
cd backend
export OPENAI_API_KEY=sk-your-key-here
npm start
```

Server listens on port 3000. The app will call `http://localhost:3000` only when using the Simulator against your machine (see iOS setup below); for a real device or TestFlight use a deployed URL.

## Deploy (pick one)

### Railway

1. [railway.app](https://railway.app) → New Project → Deploy from GitHub (or “Empty project” and connect repo).
2. Add a service: **Deploy from GitHub** → select your repo, set **Root Directory** to `backend` (or push only the backend folder).
3. In the service: **Variables** → add `OPENAI_API_KEY` = your key.
4. Deploy. Note the public URL (e.g. `https://your-app.up.railway.app`). No extra config needed; Railway runs `npm start` by default if you have a `package.json` in the deploy root.

### Render

1. [render.com](https://render.com) → New → Web Service.
2. Connect repo, set **Root Directory** to `backend`.
3. **Build command:** (leave empty or `npm install`)  
   **Start command:** `npm start`
4. **Environment** → add `OPENAI_API_KEY`.
5. Deploy. Use the service URL as the base URL in the app (e.g. `https://the-workout-log.onrender.com`).

### Fly.io

```bash
cd backend
fly launch
# set OPENAI_API_KEY when prompted or: fly secrets set OPENAI_API_KEY=sk-...
fly deploy
```

Use `https://your-app-name.fly.dev` as the base URL.

---

## API

- **GET** `/health` — returns `{"ok":true,"service":"fitlog-ai-proxy"}`. Does **not** call OpenAI. The iOS app pings this on launch when using this base URL so hosts that sleep after idle (e.g. Render free tier) start warming up before the user needs AI features.

Single forwarding endpoint, same shape as OpenAI Chat Completions (so the iOS app can call it the same way):

- **POST** `/v1/chat/completions`
- **Body:** `{ "messages": [{"role":"system","content":"..."},{"role":"user","content":"..."}], "max_tokens": 500 }`
- **Response:** Same as [OpenAI Chat Completions](https://platform.openai.com/docs/api-reference/chat/create). The server forces `model: "gpt-4o-mini"` and adds the API key.

No auth required from the client (the server’s key is used). For production you can add API keys or rate limiting later.
