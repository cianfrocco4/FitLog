# FitLog Build Config Verification

Last verified during pre-submission gap fixes.

## Privacy manifest (`PrivacyInfo.xcprivacy`)

- Source: `FitLog/PrivacyInfo.xcprivacy`
- Included via Xcode synchronized root group (`FitLog/` folder); only `Info.plist` is in `membershipExceptions`, so the privacy manifest is bundled automatically.
- After building, confirm inside the app bundle:

```bash
xcodebuild -scheme FitLog -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build
APP=$(find ~/Library/Developer/Xcode/DerivedData -name 'FitLog.app' -path '*Build/Products/*' | head -1)
plutil -p "$APP/PrivacyInfo.xcprivacy"
```

## App Group

- **Removed for v1.** `FitLogIntentBridge` uses `UserDefaults.standard` because App Intents run in-process with `openAppWhenRun = true`.
- `com.apple.security.application-groups` removed from `FitLog/FitLog.entitlements`.

## Proxy shared secret (Release)

| Location | Key |
|----------|-----|
| iOS (Release) | `Config/Secrets.release.xcconfig` → `FITLOG_PROXY_SHARED_SECRET` (gitignored) |
| iOS (Release overlay) | `Config/Release.xcconfig` injects `INFOPLIST_KEY_FITLOG_PROXY_SHARED_SECRET` |
| Server | `FITLOG_PROXY_SHARED_SECRET` on Render (`backend/README.md`) |

Setup:

```bash
cp Config/Secrets.release.xcconfig.example Config/Secrets.release.xcconfig
# Edit secret when Render authRequired is true
```

Release builds with an empty secret work when the server does not require auth (`authRequired: false`).

## Deployment target

- `IPHONEOS_DEPLOYMENT_TARGET = 18.0` (lowered from 18.2 for broader device support while keeping SwiftData / iOS 18 APIs).

## Orphan widget source

- `WidgetExtensionSource/TodayPlanWidget.swift` removed (no widget extension target in project).
