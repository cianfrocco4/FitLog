#!/usr/bin/env bash
# Run N simulated-user XCUITest journeys on a local iOS Simulator.
# Each catalog persona is a distinct gym-goer (data + workflow), not a clone of the same empty app.
#
# Usage:
#   scripts/run-simulated-users.sh           # all 5 personas
#   scripts/run-simulated-users.sh 3         # first 3 catalog users
#   REPEAT=2 scripts/run-simulated-users.sh  # soak: run the selected set twice
#
# Env:
#   SIMULATOR_DESTINATION  default: platform=iOS Simulator,name=iPhone 17 Pro
#   REPEAT                 default: 1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

N="${1:-5}"
REPEAT="${REPEAT:-1}"
DEST="${SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"

if ! [[ "$N" =~ ^[0-9]+$ ]] || [[ "$N" -lt 1 ]]; then
  echo "N must be a positive integer (number of catalog users)." >&2
  exit 1
fi

TESTS=(
  "FitLogUITests/FitLogSimulatedUserUITests/testNewFreeCreatesFirstWorkout"
  "FitLogUITests/FitLogSimulatedUserUITests/testReturningFreeStartsRecentAndHistoryGate"
  "FitLogUITests/FitLogSimulatedUserUITests/testPremiumLifterSeesActiveSubscription"
  "FitLogUITests/FitLogSimulatedUserUITests/testCardioHobbyistSeesZone2Workout"
  "FitLogUITests/FitLogSimulatedUserUITests/testPlanFollowerSeesTodaysPushA"
)

CATALOG="${#TESTS[@]}"
if [[ "$N" -gt "$CATALOG" ]]; then
  echo "Catalog has ${CATALOG} distinct users. Capping N=${N} → ${CATALOG}. Set REPEAT to soak beyond that." >&2
  N="$CATALOG"
fi

FILTERS=()
for ((i = 0; i < N; i++)); do
  FILTERS+=("-only-testing:${TESTS[$i]}")
done

echo "Simulating ${N} user(s) × REPEAT=${REPEAT} on ${DEST}"
for ((r = 1; r <= REPEAT; r++)); do
  echo "--- pass ${r}/${REPEAT} ---"
  xcodebuild test \
    -project FitLog.xcodeproj \
    -scheme FitLog \
    -destination "$DEST" \
    "${FILTERS[@]}" \
    -skipPackagePluginValidation \
    -skipMacroValidation
done
