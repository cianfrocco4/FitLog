#!/usr/bin/env node
/**
 * Poll App Store Connect customer reviews and forward new ones to a Cursor
 * Automations webhook (Bearer auth required).
 *
 * Required env:
 *   APP_STORE_CONNECT_ISSUER_ID
 *   APP_STORE_CONNECT_KEY_ID
 *   APP_STORE_CONNECT_PRIVATE_KEY   (PEM contents of the .p8 key)
 *   APP_STORE_CONNECT_APP_ID        (numeric ASC app resource id)
 *   CURSOR_AUTOMATION_WEBHOOK_URL
 *   CURSOR_AUTOMATION_WEBHOOK_TOKEN
 *
 * Optional:
 *   ASC_REVIEW_STATE_PATH          (default: .asc-review-intake-state.json)
 *   ASC_REVIEW_MIN_RATING          (1-5; only forward ratings <= this; default: 5 = all)
 *   ASC_REVIEW_LIMIT               (page size, max 200; default: 50)
 *   ASC_REVIEW_DRY_RUN             (if "1", fetch + print but do not POST)
 */

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const ASC_BASE = "https://api.appstoreconnect.apple.com";

function required(name) {
  const value = process.env[name];
  if (!value || !value.trim()) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value.trim();
}

function normalizePrivateKey(raw) {
  let key = raw.trim();
  // GitHub Actions often stores multiline secrets with literal \n
  if (key.includes("\\n") && !key.includes("\n")) {
    key = key.replace(/\\n/g, "\n");
  }
  if (!key.includes("BEGIN PRIVATE KEY")) {
    key = `-----BEGIN PRIVATE KEY-----\n${key}\n-----END PRIVATE KEY-----`;
  }
  return key;
}

function base64url(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buf.toString("base64url");
}

/** App Store Connect JWT (ES256), valid ~20 minutes. */
function makeAscToken({ issuerId, keyId, privateKeyPem }) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(
    JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" })
  );
  const payload = base64url(
    JSON.stringify({
      iss: issuerId,
      iat: now,
      exp: now + 19 * 60,
      aud: "appstoreconnect-v1",
    })
  );
  const data = `${header}.${payload}`;
  const key = crypto.createPrivateKey(normalizePrivateKey(privateKeyPem));
  const signature = crypto.sign("sha256", Buffer.from(data), {
    key,
    dsaEncoding: "ieee-p1363",
  });
  return `${data}.${base64url(signature)}`;
}

async function ascFetch(token, urlPath) {
  const res = await fetch(`${ASC_BASE}${urlPath}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });
  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!res.ok) {
    throw new Error(
      `ASC ${res.status} ${urlPath}: ${typeof body === "object" ? JSON.stringify(body) : text}`
    );
  }
  return body;
}

function loadState(statePath) {
  try {
    const raw = fs.readFileSync(statePath, "utf8");
    const parsed = JSON.parse(raw);
    return {
      processedIds: Array.isArray(parsed.processedIds)
        ? parsed.processedIds
        : [],
    };
  } catch (err) {
    if (err && err.code === "ENOENT") {
      return { processedIds: [] };
    }
    throw err;
  }
}

function saveState(statePath, state) {
  const dir = path.dirname(statePath);
  fs.mkdirSync(dir, { recursive: true });
  // Keep state bounded
  const processedIds = state.processedIds.slice(-2000);
  fs.writeFileSync(
    statePath,
    JSON.stringify({ processedIds, updatedAt: new Date().toISOString() }, null, 2) +
      "\n"
  );
}

function mapReview(item) {
  const a = item.attributes || {};
  return {
    id: item.id,
    rating: a.rating,
    title: a.title || "",
    body: a.body || "",
    reviewerNickname: a.reviewerNickname || "",
    createdDate: a.createdDate || "",
    territory: a.territory || "",
  };
}

async function main() {
  const issuerId = required("APP_STORE_CONNECT_ISSUER_ID");
  const keyId = required("APP_STORE_CONNECT_KEY_ID");
  const privateKey = required("APP_STORE_CONNECT_PRIVATE_KEY");
  const appId = required("APP_STORE_CONNECT_APP_ID");
  const webhookUrl = required("CURSOR_AUTOMATION_WEBHOOK_URL");
  const webhookToken = required("CURSOR_AUTOMATION_WEBHOOK_TOKEN");

  const statePath =
    process.env.ASC_REVIEW_STATE_PATH ||
    path.join(process.cwd(), ".asc-review-intake-state.json");
  const minRating = Number(process.env.ASC_REVIEW_MIN_RATING || "5");
  const limit = Math.min(
    200,
    Math.max(1, Number(process.env.ASC_REVIEW_LIMIT || "50"))
  );
  const dryRun = process.env.ASC_REVIEW_DRY_RUN === "1";

  const token = makeAscToken({
    issuerId,
    keyId,
    privateKeyPem: privateKey,
  });

  const query = new URLSearchParams({
    limit: String(limit),
    sort: "-createdDate",
    "fields[customerReviews]":
      "rating,title,body,reviewerNickname,createdDate,territory",
  });

  const page = await ascFetch(
    token,
    `/v1/apps/${encodeURIComponent(appId)}/customerReviews?${query}`
  );

  const reviews = (page.data || []).map(mapReview);
  const state = loadState(statePath);
  const seen = new Set(state.processedIds);

  const fresh = reviews.filter((r) => {
    if (seen.has(r.id)) return false;
    if (typeof r.rating === "number" && r.rating > minRating) return false;
    return true;
  });

  console.log(
    JSON.stringify(
      {
        fetched: reviews.length,
        newToForward: fresh.length,
        minRating,
        dryRun,
      },
      null,
      2
    )
  );

  if (fresh.length === 0) {
    return;
  }

  const payload = {
    source: "app-store-connect",
    appId,
    fetchedAt: new Date().toISOString(),
    instructionPrefix: "review:",
    reviews: fresh,
  };

  if (dryRun) {
    console.log(JSON.stringify(payload, null, 2));
    return;
  }

  const res = await fetch(webhookUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${webhookToken}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(payload),
  });

  const responseText = await res.text();
  if (!res.ok) {
    throw new Error(
      `Cursor webhook ${res.status}: ${responseText.slice(0, 500)}`
    );
  }

  for (const r of fresh) {
    state.processedIds.push(r.id);
  }
  saveState(statePath, state);

  console.log(
    JSON.stringify(
      {
        forwarded: fresh.length,
        webhookStatus: res.status,
        reviewIds: fresh.map((r) => r.id),
      },
      null,
      2
    )
  );
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});
