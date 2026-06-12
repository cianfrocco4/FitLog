#!/usr/bin/env bash
# Capture App Store screenshots from the iOS Simulator.
# Requires: Xcode, simulators for iPhone 16 Pro Max, iPhone 16, and iPad Pro 13-inch.
#
# Usage:
#   ./scripts/capture-app-store-screenshots.sh
#
# Output: AppStoreScreenshots/<device>/NN-<name>.png

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/AppStoreScreenshots"
DERIVED="$ROOT/build/ScreenshotDerived"
BUNDLE_ID="com.acianfrocco.FitLog"

declare -a DEVICES=(
  "iPhone 16 Pro Max|6.7-inch"
  "iPhone 16|6.1-inch"
  "iPad Pro 13-inch (M4)|iPad-13"
)

build_app() {
  echo "Building FitLog for simulator..."
  xcodebuild \
    -scheme FitLog \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' \
    -derivedDataPath "$DERIVED" \
    build \
    CODE_SIGNING_ALLOWED=NO \
    >/dev/null
  APP="$DERIVED/Build/Products/Debug-iphonesimulator/FitLog.app"
  if [[ ! -d "$APP" ]] || [[ ! -f "$APP/Info.plist" ]]; then
    APP=$(find ~/Library/Developer/Xcode/DerivedData/FitLog-* -path 'Build/Products/Debug-iphonesimulator/FitLog.app' -type d 2>/dev/null | head -1)
  fi
  if [[ ! -d "$APP" ]]; then
    echo "error: FitLog.app not found" >&2
    exit 1
  fi
  echo "Using app: $APP"
}

capture_for_device() {
  local name="$1"
  local slug="$2"
  local dest_dir="$OUT/$slug"
  mkdir -p "$dest_dir"

  echo "Capturing on: $name"
  local udid
  udid=$(xcrun simctl list devices available | grep "$name (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
  if [[ -z "$udid" ]]; then
    echo "warning: simulator '$name' not found; skipping" >&2
    return
  fi

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b

  xcrun simctl uninstall "$udid" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true

  xcrun simctl launch "$udid" "$BUNDLE_ID" -fitlog-ui-testing

  sleep 4
  xcrun simctl io "$udid" screenshot "$dest_dir/01-home.png"

  echo "  → $dest_dir/01-home.png"
}

mkdir -p "$OUT"
build_app

for entry in "${DEVICES[@]}"; do
  IFS='|' read -r device slug <<< "$entry"
  capture_for_device "$device" "$slug"
done

echo ""
echo "Done. Screenshots saved under $OUT"
echo "Manually capture additional screens (active workout, History, Coach) while using the app,"
echo "then upload the required sizes in App Store Connect."
