#!/usr/bin/env bash
# Daily living-user tick: each catalog persona keeps a persistent SwiftData store and
# logs today's workout when it is a training day. History accumulates across days.
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
#   LIVING_USERS_STORE_DIR           optional host folder to restore/save stores
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

N="${1:-5}"
SETTLE_SECONDS="${SETTLE_SECONDS:-12}"
BUNDLE_ID="com.acianfrocco.FitLog"
LIVING_USERS_STORE_DIR="${LIVING_USERS_STORE_DIR:-}"

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
  mapfile -t SIM < <(python3 "$ROOT/scripts/pick-iphone-simulator.py")
  SIMULATOR_NAME="${SIMULATOR_NAME:-${SIM[0]}}"
  SIMULATOR_UDID="${SIMULATOR_UDID:-${SIM[1]}}"
fi
DEST="platform=iOS Simulator,id=${SIMULATOR_UDID}"

echo "Building Debug FitLog for ${SIMULATOR_NAME} (${SIMULATOR_UDID})"
xcodebuild build \
  -project FitLog.xcodeproj \
  -scheme FitLog \
  -configuration Debug \
  -destination "$DEST" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  CODE_SIGNING_ALLOWED=NO

APP_PATH="$(
  xcodebuild -project FitLog.xcodeproj -scheme FitLog -configuration Debug \
    -sdk iphonesimulator -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ TARGET_BUILD_DIR /{d=$2} / FULL_PRODUCT_NAME /{n=$2} END{print d "/" n}'
)"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at: ${APP_PATH}" >&2
  exit 1
fi

xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

# Create the data container, then optionally restore yesterday's stores from the host.
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" -fitlog-ui-testing >/dev/null
sleep 3
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true

DATA_CONTAINER="$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)"
APP_SUPPORT="${DATA_CONTAINER}/Library/Application Support"
DOCS="${DATA_CONTAINER}/Documents"
mkdir -p "$APP_SUPPORT" "$DOCS"

restore_living_stores() {
  [[ -n "$LIVING_USERS_STORE_DIR" && -d "$LIVING_USERS_STORE_DIR" ]] || return 0
  shopt -s nullglob
  local files=("$LIVING_USERS_STORE_DIR"/FitLogData-sim-*)
  if ((${#files[@]} > 0)); then
    echo "Restoring ${#files[@]} store file(s) from ${LIVING_USERS_STORE_DIR}"
    cp -R "$LIVING_USERS_STORE_DIR"/FitLogData-sim-* "$APP_SUPPORT/"
  fi
  if [[ -f "$LIVING_USERS_STORE_DIR/fitlog-living-ticks.jsonl" ]]; then
    cp "$LIVING_USERS_STORE_DIR/fitlog-living-ticks.jsonl" "$DOCS/"
  fi
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
  if [[ -f "$DOCS/fitlog-living-ticks.jsonl" ]]; then
    cp "$DOCS/fitlog-living-ticks.jsonl" "$LIVING_USERS_STORE_DIR/"
  fi
}

restore_living_stores

for ((i = 0; i < N; i++)); do
  persona="${PERSONAS[$i]}"
  echo "--- living tick: ${persona} ---"
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" \
    -fitlog-ui-testing \
    -fitlog-ui-persistent-store \
    -fitlog-ui-daily-living \
    -fitlog-ui-persona "$persona"
  sleep "$SETTLE_SECONDS"
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
done

save_living_stores

TICK_LOG="${DOCS}/fitlog-living-ticks.jsonl"
if [[ -f "$TICK_LOG" ]]; then
  echo "--- tick log (${TICK_LOG}) ---"
  tail -n "$N" "$TICK_LOG"
else
  echo "No tick log yet at ${TICK_LOG} (app may still be settling)."
fi

echo "Done. History lives in each FitLogData-sim-*.store (Simulator and/or LIVING_USERS_STORE_DIR)."
