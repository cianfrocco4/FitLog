#!/usr/bin/env bash
# Daily living-user tick: each catalog persona keeps a persistent SwiftData store and
# logs today's workout when it is a training day. History accumulates across days.
# After each tick the persona writes likes/dislikes/bugs and we screenshot main tabs.
#
# Local Mac: stores live in the Simulator app container.
# Cloud (GitHub Actions): set LIVING_USERS_STORE_DIR to a workspace folder that is
# cached between workflow runs so History survives ephemeral VMs.
#
# Do NOT use snapshot XCUITests for this — those reset the store.
#
# Usage:
#   scripts/run-daily-living-users.sh           # all 5 personas
#   scripts/run-daily-living-users.sh 3         # first 3
#
# Env:
#   SIMULATOR_NAME / SIMULATOR_UDID  auto-picked if unset
#   SETTLE_SECONDS                   default: 12
#   TAB_SCREENSHOT_SECONDS           default: 2
#   LIVING_USERS_STORE_DIR           optional host folder to restore/save stores
#   LIVING_USERS_SCREENSHOT_DIR      optional host folder for tab screenshots
#   LIVING_USERS_DERIVED             optional DerivedData path (default: build/LivingUsersDerived)
#   CAPTURE_LIVING_SCREENSHOTS       default: 1
#   POST_LIVING_USER_REVIEWS         default: 0 (set 1 in GitHub Actions)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

N="${1:-5}"
SETTLE_SECONDS="${SETTLE_SECONDS:-12}"
TAB_SCREENSHOT_SECONDS="${TAB_SCREENSHOT_SECONDS:-2}"
BUNDLE_ID="com.acianfrocco.FitLog"
LIVING_USERS_STORE_DIR="${LIVING_USERS_STORE_DIR:-}"
CAPTURE_LIVING_SCREENSHOTS="${CAPTURE_LIVING_SCREENSHOTS:-1}"
POST_LIVING_USER_REVIEWS="${POST_LIVING_USER_REVIEWS:-0}"
LIVING_USERS_SCREENSHOT_DIR="${LIVING_USERS_SCREENSHOT_DIR:-}"
if [[ -z "$LIVING_USERS_SCREENSHOT_DIR" && -n "$LIVING_USERS_STORE_DIR" ]]; then
  LIVING_USERS_SCREENSHOT_DIR="${LIVING_USERS_STORE_DIR}/screenshots"
fi

if ! [[ "$N" =~ ^[0-9]+$ ]] || [[ "$N" -lt 1 ]]; then
  echo "N must be a positive integer." >&2
  exit 1
fi

PERSONAS=(newFree returningFree premiumLifter cardioHobbyist planFollower)
CATALOG="${#PERSONAS[@]}"
if [[ "$N" -gt "$CATALOG" ]]; then
  echo "Catalog has ${CATALOG} users. Capping N=${N} → ${CATALOG}." >&2
  N="$CATALOG"
fi

if [[ -z "${SIMULATOR_UDID:-}" || -z "${SIMULATOR_NAME:-}" ]]; then
  # macOS /bin/bash is 3.2 — no `mapfile`. Read name/udid lines portably.
  SIM_PICK="$(python3 "$ROOT/scripts/pick-iphone-simulator.py")"
  SIMULATOR_NAME="${SIMULATOR_NAME:-$(printf '%s\n' "$SIM_PICK" | awk 'NR==1 {print; exit}')}"
  SIMULATOR_UDID="${SIMULATOR_UDID:-$(printf '%s\n' "$SIM_PICK" | awk 'NR==2 {print; exit}')}"
fi
if [[ -z "${SIMULATOR_NAME:-}" || -z "${SIMULATOR_UDID:-}" ]]; then
  echo "Could not pick an iPhone simulator (need SIMULATOR_NAME and SIMULATOR_UDID)." >&2
  exit 1
fi
DEST="platform=iOS Simulator,id=${SIMULATOR_UDID}"
# Pin DerivedData so we install FitLog.app, not the Live Activity .appex.
# Do not use `xcodebuild -scheme … -target …` (exit 64) or the last
# FULL_PRODUCT_NAME from scheme -showBuildSettings (the extension).
DERIVED="${LIVING_USERS_DERIVED:-${ROOT}/build/LivingUsersDerived}"
APP_PATH="${DERIVED}/Build/Products/Debug-iphonesimulator/FitLog.app"

echo "Building Debug FitLog for ${SIMULATOR_NAME} (${SIMULATOR_UDID})"
xcodebuild build \
  -project FitLog.xcodeproj \
  -scheme FitLog \
  -configuration Debug \
  -destination "$DEST" \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$APP_PATH" || ! -f "$APP_PATH/Info.plist" ]]; then
  echo "Built FitLog.app not found at: ${APP_PATH}" >&2
  ls -la "${DERIVED}/Build/Products/Debug-iphonesimulator" >&2 || true
  exit 1
fi
echo "App bundle: ${APP_PATH}"

# GitHub macos runners often finish bootstatus before SpringBoard accepts launches
# (FBSOpenApplicationServiceErrorDomain code 4).
if [[ -z "${SIMULATOR_READY_SECONDS:-}" ]]; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    SIMULATOR_READY_SECONDS=15
  else
    SIMULATOR_READY_SECONDS=8
  fi
fi

boot_simulator() {
  xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b
  # Do not `open -a Simulator` on GitHub Actions: it races simctl and can
  # leave the device without a registered app container (POSIX ENOENT).
  sleep "$SIMULATOR_READY_SECONDS"
}

simctl_launch() {
  local attempt
  for attempt in 1 2 3 4 5 6; do
    if xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" "$@"; then
      return 0
    fi
    echo "simctl launch failed (attempt ${attempt}/6); waiting for SpringBoard..." >&2
    xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
    sleep $((attempt * 5))
  done
  echo "simctl launch failed after 6 attempts." >&2
  return 1
}

install_app() {
  if [[ "$APP_PATH" != *.app ]]; then
    echo "Refusing to install non-app bundle: ${APP_PATH}" >&2
    return 1
  fi
  echo "Installing ${APP_PATH} onto ${SIMULATOR_UDID}"
  local attempt
  for attempt in 1 2 3 4 5 6; do
    if xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"; then
      sleep 3
      if xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" app >/dev/null 2>&1; then
        echo "Registered ${BUNDLE_ID}"
        return 0
      fi
      echo "install succeeded but app container missing (attempt ${attempt}/6)" >&2
    else
      echo "simctl install failed (attempt ${attempt}/6)" >&2
    fi
    xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null 2>&1 || true
    sleep $((attempt * 4))
  done
  echo "Failed to install ${BUNDLE_ID} on ${SIMULATOR_UDID}." >&2
  xcrun simctl listapps "$SIMULATOR_UDID" 2>/dev/null | head -50 >&2 || true
  ls -ld "$APP_PATH" >&2 || true
  return 1
}

boot_simulator
install_app

# Create the data container, then optionally restore yesterday's stores from the host.
simctl_launch -fitlog-ui-testing
sleep 3
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true

DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
APP_SUPPORT="${DATA_CONTAINER}/Library/Application Support"
DOCS="${DATA_CONTAINER}/Documents"
mkdir -p "$APP_SUPPORT" "$DOCS"

copy_doc_globs_from_store() {
  local src="$1"
  [[ -d "$src" ]] || return 0
  shopt -s nullglob
  local f
  for f in "$src"/fitlog-living-ticks.jsonl "$src"/fitlog-living-reviews.jsonl "$src"/fitlog-living-review-*.md; do
    [[ -f "$f" ]] && cp "$f" "$DOCS/"
  done
}

copy_doc_globs_to_store() {
  local dest="$1"
  mkdir -p "$dest"
  shopt -s nullglob
  local f
  for f in "$DOCS"/fitlog-living-ticks.jsonl "$DOCS"/fitlog-living-reviews.jsonl "$DOCS"/fitlog-living-review-*.md; do
    [[ -f "$f" ]] && cp "$f" "$dest/"
  done
}

restore_living_stores() {
  [[ -n "$LIVING_USERS_STORE_DIR" && -d "$LIVING_USERS_STORE_DIR" ]] || return 0
  shopt -s nullglob
  local files=("$LIVING_USERS_STORE_DIR"/FitLogData-sim-*)
  if ((${#files[@]} > 0)); then
    echo "Restoring ${#files[@]} store file(s) from ${LIVING_USERS_STORE_DIR}"
    cp -R "$LIVING_USERS_STORE_DIR"/FitLogData-sim-* "$APP_SUPPORT/"
  fi
  copy_doc_globs_from_store "$LIVING_USERS_STORE_DIR"
}

save_living_stores() {
  [[ -n "$LIVING_USERS_STORE_DIR" ]] || return 0
  mkdir -p "$LIVING_USERS_STORE_DIR"
  shopt -s nullglob
  local files=("$APP_SUPPORT"/FitLogData-sim-*)
  if ((${#files[@]} > 0)); then
    echo "Saving ${#files[@]} store file(s) to ${LIVING_USERS_STORE_DIR}"
    cp -R "$APP_SUPPORT"/FitLogData-sim-* "$LIVING_USERS_STORE_DIR/"
  fi
  copy_doc_globs_to_store "$LIVING_USERS_STORE_DIR"
}

capture_persona_tabs() {
  local persona="$1"
  [[ "$CAPTURE_LIVING_SCREENSHOTS" == "1" ]] || return 0
  [[ -n "$LIVING_USERS_SCREENSHOT_DIR" ]] || return 0
  local day dir tab
  day="$(date -u +%F)"
  dir="${LIVING_USERS_SCREENSHOT_DIR}/${persona}"
  mkdir -p "$dir"
  for tab in home plan history coach more; do
    xcrun simctl openurl "$SIMULATOR_UDID" "fitlog://uitest/tab/${tab}" >/dev/null 2>&1 || true
    sleep "$TAB_SCREENSHOT_SECONDS"
    xcrun simctl io "$SIMULATOR_UDID" screenshot "${dir}/${day}-${tab}.png"
  done
  echo "Screenshots: ${dir}/${day}-*.png"
}

restore_living_stores

for ((i = 0; i < N; i++)); do
  persona="${PERSONAS[$i]}"
  echo "--- living tick + review: ${persona} ---"
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
  simctl_launch \
    -fitlog-ui-testing \
    -fitlog-ui-persistent-store \
    -fitlog-ui-daily-living \
    -fitlog-ui-write-review \
    -fitlog-ui-persona "$persona"
  sleep "$SETTLE_SECONDS"
  capture_persona_tabs "$persona"
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
done

save_living_stores

if [[ -n "$LIVING_USERS_STORE_DIR" ]]; then
  python3 "$ROOT/scripts/assemble-living-user-inbox.py" "$LIVING_USERS_STORE_DIR"
fi

TICK_LOG="${DOCS}/fitlog-living-ticks.jsonl"
REVIEW_LOG="${DOCS}/fitlog-living-reviews.jsonl"
if [[ -f "$TICK_LOG" ]]; then
  echo "--- tick log (${TICK_LOG}) ---"
  tail -n "$N" "$TICK_LOG"
else
  echo "No tick log yet at ${TICK_LOG} (app may still be settling)."
fi
if [[ -f "$REVIEW_LOG" ]]; then
  echo "--- reviews (${REVIEW_LOG}) ---"
  tail -n "$N" "$REVIEW_LOG"
fi

if [[ "$POST_LIVING_USER_REVIEWS" == "1" && -n "$LIVING_USERS_STORE_DIR" ]]; then
  chmod +x "$ROOT/scripts/post-living-user-reviews.sh"
  "$ROOT/scripts/post-living-user-reviews.sh" "$LIVING_USERS_STORE_DIR" || true
fi

echo "Done. History lives in each FitLogData-sim-*.store; reviews in fitlog-living-reviews.jsonl."
