/**
 * FitLog AI proxy – forwards Chat Completions to OpenAI with the server's API key.
 * Deploy to Railway, Render, Fly.io, or any Node host. Set env OPENAI_API_KEY.
 *
 * POST /v1/chat/completions
 * Body: { "messages": [{"role":"system","content":"..."},{"role":"user","content":"..."}], "max_tokens": 500 }
 * (model is fixed to gpt-4o-mini on the server)
 */

const http = require('http');

const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const MODEL = 'gpt-4o-mini';

function getEnv(name) {
  const v = process.env[name];
  if (!v || !v.trim()) throw new Error(`Missing env: ${name}`);
  return v.trim();
}

async function forwardToOpenAI(apiKey, body) {
  const payload = JSON.stringify({
    model: MODEL,
    messages: body.messages,
    max_tokens: body.max_tokens ?? 500,
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

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method !== 'POST' || req.url !== '/v1/chat/completions') {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
    return;
  }

  let apiKey;
  try {
    apiKey = getEnv('OPENAI_API_KEY');
  } catch (e) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Server misconfigured: ' + e.message }));
    return;
  }

  let body;
  try {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    body = JSON.parse(Buffer.concat(chunks).toString());
  } catch {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Invalid JSON' }));
    return;
  }

  if (!Array.isArray(body.messages)) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Missing messages array' }));
    return;
  }

  try {
    const { status, body: openaiBody } = await forwardToOpenAI(apiKey, body);
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(openaiBody);
  } catch (e) {
    res.writeHead(502, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Proxy error: ' + (e.message || 'Unknown') }));
  }
});

const port = process.env.PORT || 3000;
server.listen(port, () => {
  console.log('FitLog AI proxy listening on port', port);
});
