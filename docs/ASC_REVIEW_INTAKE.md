# App Store review → Cursor automation intake

Hands-off path: **GitHub Actions** polls App Store Connect every 6 hours, then POSTs new customer reviews to a **Cursor Automations webhook**. The cloud agent triages them and opens a draft PR when the fix is clear and low-risk.

Manual fallback: paste a review into Slack `#workoutlogai-agents` as `review: …` (separate Slack-triggered automation).

## 1. Create an App Store Connect API key

1. Open [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Create a key with access that can read customer reviews (typically **Admin** or **App Manager**).
3. Download the `.p8` once. Note:
   - **Issuer ID** (page header)
   - **Key ID**
   - **Private key** file contents
4. Find your numeric **App ID**:
   - Apps → **Workout Log AI** → App Information → **Apple ID** (numeric), **or**
   - `GET https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=com.acianfrocco.FitLog` with a JWT from this key.

## 2. Create the Cursor webhook automation

Create **FitLog ASC Review Webhook** in Cursor Automations (webhook trigger, repo `cianfrocco4/FitLog`, branch `main`).

After you **save** the automation:

1. Copy the **webhook URL**.
2. Generate / copy the **Bearer API key**.

These go into GitHub secrets below. Cursor requires:

```http
Authorization: Bearer <CURSOR_AUTOMATION_WEBHOOK_TOKEN>
```

## 3. GitHub repository secrets

Repo → **Settings → Secrets and variables → Actions**. Add:

| Secret | Value |
|--------|--------|
| `APP_STORE_CONNECT_ISSUER_ID` | ASC Issuer ID |
| `APP_STORE_CONNECT_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Full `.p8` PEM (or key body; `\n` escapes OK) |
| `APP_STORE_CONNECT_APP_ID` | Numeric Apple/App resource ID |
| `CURSOR_AUTOMATION_WEBHOOK_URL` | From the saved Cursor automation |
| `CURSOR_AUTOMATION_WEBHOOK_TOKEN` | Bearer token from that automation |

Optional **variable** `ASC_REVIEW_MIN_RATING` (default `3`): only forward reviews with rating ≤ this value. Set `5` to forward all ratings.

## 4. Enable and test

1. Push the workflow on `main` (`.github/workflows/asc-review-intake.yml`).
2. Actions → **ASC Review Intake** → **Run workflow**.
3. Confirm a Cursor Automations run starts when new ≤3★ reviews exist.
4. Slack `#workoutlogai-agents` should get the agent summary / PR link (from the automation’s Slack action).

### Local dry run

```bash
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_KEY_ID=...
export APP_STORE_CONNECT_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"
export APP_STORE_CONNECT_APP_ID=...
export CURSOR_AUTOMATION_WEBHOOK_URL=https://example.invalid
export CURSOR_AUTOMATION_WEBHOOK_TOKEN=dummy
export ASC_REVIEW_DRY_RUN=1
node scripts/asc-review-intake/fetch-and-forward.mjs
```

## Payload shape (sent to Cursor)

```json
{
  "source": "app-store-connect",
  "appId": "1234567890",
  "fetchedAt": "2026-08-07T12:00:00.000Z",
  "instructionPrefix": "review:",
  "reviews": [
    {
      "id": "…",
      "rating": 2,
      "title": "…",
      "body": "…",
      "reviewerNickname": "…",
      "createdDate": "…",
      "territory": "USA"
    }
  ]
}
```

## Safety

- Never commit `.p8` keys, webhook tokens, or `.asc-review-intake-state.json`.
- The agent must open **draft PRs only** and never merge.
- Ambiguous feature requests should be Slack-triaged, not auto-implemented.
