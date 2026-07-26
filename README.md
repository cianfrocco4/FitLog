# Workout Log AI

A local-first iOS strength-training app built with **SwiftUI**, **SwiftData**, and optional **Apple Health** readiness scoring. Log workouts, track readiness from sleep/HRV/resting HR, and unlock AI coaching with **Premium**.

## Core features (free)

- Workout logging, rest timer, and Live Activity
- Manual plans, templates, and custom exercises
- Today's **Readiness Score** (training load + optional Apple Health)
- Home screen readiness widget and quick-log deep link
- Basic history (7–14 day ranges)
- Deterministic coach recommendations (no cloud AI)

## Premium

- AI Coach chat, program generation, form tips, and workout suggestions
- Readiness trends (7–90 days)
- Advanced analytics, unlimited history, and data export

Subscriptions are managed via **RevenueCat** and App Store In-App Purchases.

## Requirements

- Xcode 16+
- iOS 18+
- SwiftData with explicit schema migrations (V1→V6)

## Build & run

1. Clone the repo and open `FitLog.xcodeproj`
2. For local IAP testing, the **FitLog** scheme uses `Configuration.storekit`
3. Set `REVENUECAT_API_KEY` in the scheme environment or `Info.plist` for purchase flows
4. Build & Run (⌘R)

See [docs/REVENUECAT_SETUP.md](docs/REVENUECAT_SETUP.md) for subscription configuration.

## Data & privacy

- Workout data is stored on-device with SwiftData
- Readiness uses on-device scoring from Apple Health metrics you authorize
- Cloud AI features require Premium and send workout context to the configured proxy

See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) and [docs/APP_STORE_COMPLIANCE.md](docs/APP_STORE_COMPLIANCE.md).
