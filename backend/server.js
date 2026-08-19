/**
 * FitLog backend proxy – OpenAI Chat Completions + MuscleWiki form guide.
 * Deploy to Railway, Render, Fly.io, or any Node host.
 *
 * Env:
 *   OPENAI_API_KEY              (required for /v1/chat/completions)
 *   OPENAI_MODEL                (optional) e.g. gpt-4o-mini. Default: gpt-4o-mini
 *   MUSCLEWIKI_API_KEY          (required for /v1/form-guide/* routes)
 *   FITLOG_PROXY_SHARED_SECRET  (required in production / when REQUIRE_PROXY_SECRET=1)
 *   REQUIRE_PROXY_SECRET        (optional) "1" to fail closed without secret even outside production
 *   CHAT_RATE_LIMIT_PER_MIN     (optional) default 10
 *   CHAT_RATE_LIMIT_PER_DAY     (optional) default 100
 *   FORM_GUIDE_RATE_LIMIT_PER_MIN / `_PER_DAY` (optional) default 30 / 300
 *   FORM_GUIDE_STREAM_RATE_LIMIT_PER_MIN (optional) default 300 (AVPlayer Range requests)
 *   MAX_CHAT_TOKENS             (optional) default 2048
 *   MAX_CHAT_MESSAGES           (optional) default 24
 *   MAX_CHAT_CHARS              (optional) default 40000
 *   ALLOW_FORM_GUIDE_STREAM     (optional) "0" to disable branded video proxy (default enabled)
 *
 * GET  /health
 * POST /v1/chat/completions
 * GET  /v1/form-guide/search?q=&limit=
 * GET  /v1/form-guide/exercises/:id
 * GET  /v1/form-guide/stream/videos/branded/:filename
 */

const http = require('http');
const crypto = require('crypto');

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const MUSCLEWIKI_BASE = 'https://api.musclewiki.com';
const DEFAULT_MODEL = 'gpt-4o-mini';
const MINUTE_MS = 60_000;
const DAY_MS = 24 * 60 * 60 * 1000;

function envInt(name, fallback) {
  const raw = process.env[name];
  if (raw == null || !String(raw).trim()) return fallback;
  const n = Number.parseInt(String(raw).trim(), 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

const MAX_CHAT_TOKENS = envInt('MAX_CHAT_TOKENS', 2048);
const MAX_CHAT_MESSAGES = envInt('MAX_CHAT_MESSAGES', 24);
const MAX_CHAT_CHARS = envInt('MAX_CHAT_CHARS', 40_000);
const CHAT_RATE_LIMIT_PER_MIN = envInt('CHAT_RATE_LIMIT_PER_MIN', 10);
const CHAT_RATE_LIMIT_PER_DAY = envInt('CHAT_RATE_LIMIT_PER_DAY', 100);
const FORM_GUIDE_RATE_LIMIT_PER_MIN = envInt('FORM_GUIDE_RATE_LIMIT_PER_MIN', 30);
const FORM_GUIDE_RATE_LIMIT_PER_DAY = envInt('FORM_GUIDE_RATE_LIMIT_PER_DAY', 300);
const FORM_GUIDE_STREAM_RATE_LIMIT_PER_MIN = envInt('FORM_GUIDE_STREAM_RATE_LIMIT_PER_MIN', 300);
const ALLOW_FORM_GUIDE_STREAM = process.env.ALLOW_FORM_GUIDE_STREAM !== '0';

function getModel() {
  const v = process.env.OPENAI_MODEL;
  return (v && v.trim()) ? v.trim() : DEFAULT_MODEL;
}

function getEnv(name) {
  const v = process.env[name];
  if (!v || !v.trim()) throw new Error(`Missing env: ${name}`);
  return v.trim();
}

function getOptionalEnv(name) {
  const v = process.env[name];
  return (v && v.trim()) ? v.trim() : null;
}

function requiresProxySecret() {
  if (process.env.REQUIRE_PROXY_SECRET === '1') return true;
  return process.env.NODE_ENV === 'production';
}

function pathOnly(url) {
  if (!url) return '';
  const q = url.indexOf('?');
  return q === -1 ? url : url.slice(0, q);
}

function queryString(url) {
  if (!url) return '';
  const q = url.indexOf('?');
  return q === -1 ? '' : url.slice(q);
}

function sendJSON(res, status, payload) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(payload));
}

const rateBuckets = new Map();

function clientKey(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.socket.remoteAddress || 'unknown';
}

function hashIP(ip) {
  return crypto.createHash('sha256').update(String(ip)).digest('hex').slice(0, 12);
}

function consumeRateLimit(key, limit, windowMs) {
  const now = Date.now();
  const bucket = rateBuckets.get(key) || { count: 0, resetAt: now + windowMs };
  if (now >= bucket.resetAt) {
    bucket.count = 0;
    bucket.resetAt = now + windowMs;
  }
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return bucket.count <= limit;
}

function verifyProxyAuth(req, res) {
  const secret = getOptionalEnv('FITLOG_PROXY_SHARED_SECRET');
  if (!secret) {
    if (requiresProxySecret()) {
      sendJSON(res, 503, { error: 'Proxy misconfigured: FITLOG_PROXY_SHARED_SECRET required' });
      return false;
    }
    return true;
  }
  const provided = req.headers['x-fitlog-proxy-secret'];
  if (provided === secret) return true;
  sendJSON(res, 401, { error: 'Unauthorized' });
  return false;
}

function enforceRateLimits(req, res, { perMin, perDay, kind }) {
  const ip = clientKey(req);
  const minKey = `${kind}:min:${ip}`;
  const dayKey = `${kind}:day:${ip}`;
  if (!consumeRateLimit(minKey, perMin, MINUTE_MS)) {
    sendJSON(res, 429, { error: 'Rate limit exceeded' });
    return false;
  }
  if (!consumeRateLimit(dayKey, perDay, DAY_MS)) {
    sendJSON(res, 429, { error: 'Daily rate limit exceeded' });
    return false;
  }
  return true;
}

function validateChatBody(body) {
  if (!body || !Array.isArray(body.messages)) {
    return { ok: false, error: 'Missing messages array' };
  }
  if (body.messages.length === 0 || body.messages.length > MAX_CHAT_MESSAGES) {
    return { ok: false, error: `messages must contain 1–${MAX_CHAT_MESSAGES} items` };
  }
  let totalChars = 0;
  for (const msg of body.messages) {
    if (!msg || typeof msg !== 'object') {
      return { ok: false, error: 'Invalid message entry' };
    }
    const content = typeof msg.content === 'string' ? msg.content : JSON.stringify(msg.content ?? '');
    totalChars += content.length;
  }
  if (totalChars > MAX_CHAT_CHARS) {
    return { ok: false, error: 'Request body too large' };
  }
  return { ok: true };
}

async function forwardToOpenAI(apiKey, body) {
  const model = getModel();
  const requestedTokens = Number.isFinite(body.max_tokens) ? body.max_tokens : 500;
  const maxTokens = Math.min(Math.max(1, requestedTokens), MAX_CHAT_TOKENS);
  const payload = JSON.stringify({
    model,
    messages: body.messages,
    max_tokens: maxTokens,
  });
  const res = await fetch(OPENAI_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: payload,
  });
  const data = await res.text();
  return { status: res.status, body: data, maxTokens };
}

async function forwardMuscleWikiGET(upstreamPath, reqQuery, req, res, options = {}) {
  const apiKey = getOptionalEnv('MUSCLEWIKI_API_KEY');
  if (!apiKey) {
    sendJSON(res, 503, { error: 'Form guide proxy not configured: missing MUSCLEWIKI_API_KEY' });
    return;
  }

  const upstreamURL = `${MUSCLEWIKI_BASE}${upstreamPath}${reqQuery}`;
  const headers = { 'X-API-Key': apiKey };
  if (req.headers.range) {
    headers.Range = req.headers.range;
  }

  const method = req.method === 'HEAD' ? 'HEAD' : 'GET';

  try {
    const upstream = await fetch(upstreamURL, { method, headers });
    const responseHeaders = {};
    const contentType = upstream.headers.get('content-type');
    if (contentType) {
      responseHeaders['Content-Type'] = contentType;
    } else if (options.stream) {
      responseHeaders['Content-Type'] = 'video/mp4';
    }
    const contentLength = upstream.headers.get('content-length');
    if (contentLength) responseHeaders['Content-Length'] = contentLength;
    const acceptRanges = upstream.headers.get('accept-ranges');
    if (acceptRanges) {
      responseHeaders['Accept-Ranges'] = acceptRanges;
    } else if (options.stream) {
      responseHeaders['Accept-Ranges'] = 'bytes';
    }
    const contentRange = upstream.headers.get('content-range');
    if (contentRange) responseHeaders['Content-Range'] = contentRange;

    res.writeHead(upstream.status, responseHeaders);

    if (req.method === 'HEAD') {
      res.end();
      return;
    }

    if (!upstream.body) {
      res.end();
      return;
    }

    const reader = upstream.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      res.write(Buffer.from(value));
    }
    res.end();
  } catch (e) {
    sendJSON(res, 502, { error: 'Form guide proxy error: ' + (e.message || 'Unknown') });
  }
}

function logProxyCall({ kind, req, status, approxTokens }) {
  const ipHash = hashIP(clientKey(req));
  const tokenPart = approxTokens != null ? ` tokens≈${approxTokens}` : '';
  console.log(`[proxy] kind=${kind} status=${status} ip=${ipHash}${tokenPart}`);
}

async function handleChatCompletions(req, res) {
  if (!verifyProxyAuth(req, res)) return;
  if (!enforceRateLimits(req, res, {
    perMin: CHAT_RATE_LIMIT_PER_MIN,
    perDay: CHAT_RATE_LIMIT_PER_DAY,
    kind: 'chat',
  })) return;

  let apiKey;
  try {
    apiKey = getEnv('OPENAI_API_KEY');
  } catch (e) {
    sendJSON(res, 500, { error: 'Server misconfigured: ' + e.message });
    return;
  }

  let body;
  try {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    body = JSON.parse(Buffer.concat(chunks).toString());
  } catch {
    sendJSON(res, 400, { error: 'Invalid JSON' });
    return;
  }

  const validation = validateChatBody(body);
  if (!validation.ok) {
    sendJSON(res, 400, { error: validation.error });
    return;
  }

  try {
    const { status, body: openaiBody, maxTokens } = await forwardToOpenAI(apiKey, body);
    logProxyCall({ kind: 'chat', req, status, approxTokens: maxTokens });
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(openaiBody);
  } catch (e) {
    logProxyCall({ kind: 'chat', req, status: 502 });
    sendJSON(res, 502, { error: 'Proxy error: ' + (e.message || 'Unknown') });
  }
}

function handleFormGuideRoute(path, reqQuery, req, res) {
  if (!verifyProxyAuth(req, res)) return true;

  const searchPrefix = '/v1/form-guide/search';
  const exercisePrefix = '/v1/form-guide/exercises/';
  const streamPrefix = '/v1/form-guide/stream/videos/branded/';
  const isStream = path.startsWith(streamPrefix);

  if (isStream) {
    // AVPlayer issues many Range requests per clip; do not share the JSON API budget.
    if (!enforceRateLimits(req, res, {
      perMin: FORM_GUIDE_STREAM_RATE_LIMIT_PER_MIN,
      perDay: FORM_GUIDE_STREAM_RATE_LIMIT_PER_MIN * 24,
      kind: 'form-stream',
    })) return true;
  } else if (!enforceRateLimits(req, res, {
    perMin: FORM_GUIDE_RATE_LIMIT_PER_MIN,
    perDay: FORM_GUIDE_RATE_LIMIT_PER_DAY,
    kind: 'form',
  })) {
    return true;
  }

  if (path === searchPrefix) {
    logProxyCall({ kind: 'form-search', req, status: 200 });
    forwardMuscleWikiGET('/search', reqQuery, req, res);
    return true;
  }

  if (path.startsWith(exercisePrefix)) {
    const id = path.slice(exercisePrefix.length);
    if (!/^\d+$/.test(id)) {
      sendJSON(res, 400, { error: 'Invalid exercise id' });
      return true;
    }
    logProxyCall({ kind: 'form-exercise', req, status: 200 });
    forwardMuscleWikiGET(`/exercises/${id}`, '', req, res);
    return true;
  }

  if (isStream) {
    if (!ALLOW_FORM_GUIDE_STREAM) {
      sendJSON(res, 404, { error: 'Video streaming disabled' });
      return true;
    }
    const filename = decodeURIComponent(path.slice(streamPrefix.length));
    if (!filename || filename.includes('/') || filename.includes('..')) {
      sendJSON(res, 400, { error: 'Invalid stream filename' });
      return true;
    }
    logProxyCall({ kind: 'form-stream', req, status: 200 });
    forwardMuscleWikiGET(`/stream/videos/branded/${filename}`, '', req, res, { stream: true });
    return true;
  }

  return false;
}

const server = http.createServer(async (req, res) => {
  // iOS clients do not need browser CORS; keep preflight minimal without wide-open *.
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Range, X-FitLog-Proxy-Secret');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const path = pathOnly(req.url);
  const reqQuery = queryString(req.url);

  if (path === '/health' || path === '/') {
    if (req.method === 'GET' || req.method === 'HEAD') {
      const secret = getOptionalEnv('FITLOG_PROXY_SHARED_SECRET');
      const payload = {
        ok: true,
        service: 'fitlog-proxy',
        formGuide: getOptionalEnv('MUSCLEWIKI_API_KEY') != null,
        authRequired: secret != null || requiresProxySecret(),
        streamEnabled: ALLOW_FORM_GUIDE_STREAM,
      };
      res.writeHead(200, { 'Content-Type': 'application/json' });
      if (req.method === 'GET') {
        res.end(JSON.stringify(payload));
      } else {
        res.end();
      }
      return;
    }
  }

  if ((req.method === 'GET' || req.method === 'HEAD') && handleFormGuideRoute(path, reqQuery, req, res)) {
    return;
  }

  if (req.method === 'POST' && path === '/v1/chat/completions') {
    await handleChatCompletions(req, res);
    return;
  }

  sendJSON(res, 404, { error: 'Not found' });
});

const port = process.env.PORT || 3000;
server.listen(port, () => {
  console.log('FitLog proxy listening on port', port);
  if (requiresProxySecret() && !getOptionalEnv('FITLOG_PROXY_SHARED_SECRET')) {
    console.warn('[proxy] WARNING: production/REQUIRE_PROXY_SECRET set but FITLOG_PROXY_SHARED_SECRET is missing — protected routes return 503');
  }
});
