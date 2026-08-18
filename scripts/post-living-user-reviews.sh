#!/usr/bin/env bash
# Find or create the standing "Living user feedback inbox" GitHub issue and
# comment with living-users/INBOX.md. Soft-fails so a missing token does not
# fail the living-users job.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STORE_DIR="${1:-${LIVING_USERS_STORE_DIR:-$ROOT/living-users}}"
INBOX="$STORE_DIR/INBOX.md"
ISSUE_TITLE="Living user feedback inbox"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh not found; skip posting living-user reviews." >&2
  exit 0
fi

if [[ ! -f "$INBOX" ]]; then
  python3 "$ROOT/scripts/assemble-living-user-inbox.py" "$STORE_DIR"
fi
if [[ ! -f "$INBOX" ]]; then
  echo "No INBOX.md at ${INBOX}; skip posting." >&2
  exit 0
fi

REPO="${GITHUB_REPOSITORY:-}"
if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [[ -z "$REPO" ]]; then
  echo "Could not resolve GitHub repo; skip posting." >&2
  exit 0
fi

ISSUE_NUMBER="${FITLOG_LIVING_USERS_ISSUE_NUMBER:-}"
if [[ -z "$ISSUE_NUMBER" ]]; then
  ISSUE_NUMBER="$(
    gh issue list --repo "$REPO" --state open --search "${ISSUE_TITLE} in:title" \
      --json number,title --jq \
      "[.[] | select(.title == \"${ISSUE_TITLE}\")] | .[0].number // empty" \
      2>/dev/null || true
  )"
  ISSUE_NUMBER="$(printf '%s' "$ISSUE_NUMBER" | tr -d '[:space:]')"
fi

if [[ -z "$ISSUE_NUMBER" ]]; then
  BODY_CREATE="$(mktemp)"
  cat > "$BODY_CREATE" <<'EOF'
This issue is the **inbox for simulated living users** (personas that log workouts on the daily GitHub Action).

Each comment is one day's likes, dislikes, bugs, and UI/workflow notes, generated from their SwiftData stores. Tab screenshots live on the workflow artifact `living-user-screenshots`.

The nightly improvement loop should read the latest comment (or `living-users/INBOX.md` from the `living-user-stores` artifact) before picking product work.

Leave this issue open while the Living users workflow is active.
EOF
  ISSUE_URL="$(gh issue create --repo "$REPO" --title "$ISSUE_TITLE" --body-file "$BODY_CREATE" || true)"
  rm -f "$BODY_CREATE"
  ISSUE_NUMBER="${ISSUE_URL##*/}"
fi

if [[ -z "$ISSUE_NUMBER" ]]; then
  echo "Could not find or create inbox issue; skip posting." >&2
  exit 0
fi

BODY="$(mktemp)"
{
  if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
    echo "From [Living users run ${GITHUB_RUN_ID}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})."
    echo
  fi
  cat "$INBOX"
} > "$BODY"

if gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body-file "$BODY"; then
  echo "Posted living-user inbox to https://github.com/${REPO}/issues/${ISSUE_NUMBER}"
else
  echo "Failed to comment on issue ${ISSUE_NUMBER} (missing issues:write?)." >&2
fi
rm -f "$BODY"
