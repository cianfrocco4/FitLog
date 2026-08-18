#!/usr/bin/env bash
# Daily living-user tick: each catalog persona keeps a persistent SwiftData store and
# logs today's workout when it is a training day. History accumulates across days.
#
# Do NOT use XCUITest for this — those tests reset the store. This launches the Debug
# app on the Simulator with -fitlog-ui-daily-living.
#
# Usage:
#   scripts/run-daily-living-users.sh           # all 5 personas
#   scripts/run-daily-living-users.sh 3         # first 3
#
# Env:
#   SIMULATOR_NAME   default: iPhone 17 Pro
#   SETTLE_SECONDS   default: 12 (time for onAppear seed)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

N="${1:-5}"
SETTLE_SECONDS="${SETTLE_SECONDS:-12}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
BUNDLE_ID="com.acianfrocco.FitLog"
DEST="platform=iOS Simulator,name=${SIMULATOR_NAME}"

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

echo "Building Debug FitLog for ${DEST}"
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

xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_NAME" -b
xcrun simctl install booted "$APP_PATH"

for ((i = 0; i < N; i++)); do
  persona="${PERSONAS[$i]}"
  echo "--- living tick: ${persona} ---"
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch booted "$BUNDLE_ID" \
    -fitlog-ui-testing \
    -fitlog-ui-persistent-store \
    -fitlog-ui-daily-living \
    -fitlog-ui-persona "$persona"
  sleep "$SETTLE_SECONDS"
  xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
done

DATA_CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE_ID" data 2>/dev/null || true)"
TICK_LOG="${DATA_CONTAINER}/Documents/fitlog-living-ticks.jsonl"
if [[ -f "$TICK_LOG" ]]; then
  echo "--- tick log (${TICK_LOG}) ---"
  tail -n "$N" "$TICK_LOG"
else
  echo "No tick log yet at ${TICK_LOG:-unknown} (app may still be settling)."
fi

echo "Done. Re-run this script tomorrow to append History. Browse a user with:"
echo "  xcrun simctl launch booted ${BUNDLE_ID} -fitlog-ui-testing -fitlog-ui-persistent-store -fitlog-ui-persona returningFree"
