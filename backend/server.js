/**
 * FitLog backend proxy – OpenAI Chat Completions + MuscleWiki form guide.
 * Deploy to Railway, Render, Fly.io, or any Node host.
 *
 * Env:
 *   OPENAI_API_KEY              (required for /v1/chat/completions)
 *   OPENAI_MODEL                (optional) e.g. gpt-4o-mini. Default: gpt-4o-mini
 *   MUSCLEWIKI_API_KEY          (required for /v1/form-guide/* routes)
 *   FITLOG_PROXY_SHARED_SECRET  (recommended) shared secret for app requests
 *
 * GET  /health
 * POST /v1/chat/completions
 * GET  /v1/form-guide/search?q=&limit=
 * GET  /v1/form-guide/exercises/:id
 * GET  /v1/form-guide/stream/videos/branded/:filename
 */

const http = require('http');

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const MUSCLEWIKI_BASE = 'https://api.musclewiki.com';
const DEFAULT_MODEL = 'gpt-4o-mini';
const MAX_CHAT_TOKENS = 4096;
const CHAT_RATE_LIMIT = 30;
const FORM_GUIDE_RATE_LIMIT = 120;
const RATE_WINDOW_MS = 60_000;

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

function consumeRateLimit(key, limit) {
  const now = Date.now();
  const bucket = rateBuckets.get(key) || { count: 0, resetAt: now + RATE_WINDOW_MS };
  if (now >= bucket.resetAt) {
    bucket.count = 0;
    bucket.resetAt = now + RATE_WINDOW_MS;
  }
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return bucket.count <= limit;
}

function verifyProxyAuth(req, res) {
  const secret = getOptionalEnv('FITLOG_PROXY_SHARED_SECRET');
  if (!secret) return true;
  const provided = req.headers['x-fitlog-proxy-secret'];
  if (provided === secret) return true;
  sendJSON(res, 401, { error: 'Unauthorized' });
  return false;
}

function enforceRateLimit(req, res, limit) {
  const key = `${clientKey(req)}:${limit}`;
  if (consumeRateLimit(key, limit)) return true;
  sendJSON(res, 429, { error: 'Rate limit exceeded' });
  return false;
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
  return { status: res.status, body: data };
}

async function forwardMuscleWikiGET(upstreamPath, reqQuery, req, res) {
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

  try {
    const upstream = await fetch(upstreamURL, { method: 'GET', headers });
    const responseHeaders = {};
    const contentType = upstream.headers.get('content-type');
    if (contentType) responseHeaders['Content-Type'] = contentType;
    const contentLength = upstream.headers.get('content-length');
    if (contentLength) responseHeaders['Content-Length'] = contentLength;
    const acceptRanges = upstream.headers.get('accept-ranges');
    if (acceptRanges) responseHeaders['Accept-Ranges'] = acceptRanges;
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

async function handleChatCompletions(req, res) {
  if (!verifyProxyAuth(req, res)) return;
  if (!enforceRateLimit(req, res, CHAT_RATE_LIMIT)) return;

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

  if (!Array.isArray(body.messages)) {
    sendJSON(res, 400, { error: 'Missing messages array' });
    return;
  }

  try {
    const { status, body: openaiBody } = await forwardToOpenAI(apiKey, body);
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(openaiBody);
  } catch (e) {
    sendJSON(res, 502, { error: 'Proxy error: ' + (e.message || 'Unknown') });
  }
}

function handleFormGuideRoute(path, reqQuery, req, res) {
  if (!verifyProxyAuth(req, res)) return true;
  if (!enforceRateLimit(req, res, FORM_GUIDE_RATE_LIMIT)) return true;

  const searchPrefix = '/v1/form-guide/search';
  const exercisePrefix = '/v1/form-guide/exercises/';
  const streamPrefix = '/v1/form-guide/stream/videos/branded/';

  if (path === searchPrefix) {
    forwardMuscleWikiGET('/search', reqQuery, req, res);
    return true;
  }

  if (path.startsWith(exercisePrefix)) {
    const id = path.slice(exercisePrefix.length);
    if (!/^\d+$/.test(id)) {
      sendJSON(res, 400, { error: 'Invalid exercise id' });
      return true;
    }
    forwardMuscleWikiGET(`/exercises/${id}`, '', req, res);
    return true;
  }

  if (path.startsWith(streamPrefix)) {
    const filename = decodeURIComponent(path.slice(streamPrefix.length));
    if (!filename || filename.includes('/') || filename.includes('..')) {
      sendJSON(res, 400, { error: 'Invalid stream filename' });
      return true;
    }
    forwardMuscleWikiGET(`/stream/videos/branded/${filename}`, '', req, res);
    return true;
  }

  return false;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
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
      const payload = {
        ok: true,
        service: 'fitlog-proxy',
        formGuide: getOptionalEnv('MUSCLEWIKI_API_KEY') != null,
        authRequired: getOptionalEnv('FITLOG_PROXY_SHARED_SECRET') != null,
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
});
