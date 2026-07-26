# RevenueCat setup (Workout Log AI)

## 1. App Store Connect products

Create auto-renewable subscriptions:

| Product ID | Price | Notes |
|---|---|---|
| `workoutlogai_premium_monthly` | $5.99/mo | 14-day free trial recommended |
| `workoutlogai_premium_annual` | $49.99/yr | 14-day free trial recommended |
| `workoutlogai_premium_lifetime` | optional | Early adopter lifetime (non-consumable IAP) |

Create a subscription group **Workout Log AI Premium**.

## 2. RevenueCat project

1. Create a project at [RevenueCat](https://www.revenuecat.com/).
2. Add the iOS app with bundle ID `com.acianfrocco.FitLog`.
3. Create entitlement **`premium`** (must match `RevenueCatConfig.premiumEntitlementID`).
4. Attach all products to the `premium` entitlement.
5. Create offering **`default`** with monthly + annual (+ lifetime) packages.
6. Mark that offering as **Current** in RevenueCat (the app loads `offerings.current`, not a hardcoded offering ID).

## 3. API key in the app

The **public** iOS SDK key (`appl_…`) is already set in `FitLog/Info.plist` for Phase 1. You may override via Xcode scheme environment variable `REVENUECAT_API_KEY` for local experiments.

Do **not** put the RevenueCat **secret** API key in the app.

### Operator checklist (App Store Connect + RevenueCat)

Do these in order before TestFlight purchase testing:

- [ ] App Store Connect → **Agreements, Tax, and Banking** complete (Paid Apps Agreement)
- [ ] **Users and Access → Sandbox** → create a Sandbox Apple ID
- [ ] **Subscriptions** → create group **Workout Log AI Premium**
- [ ] Add `workoutlogai_premium_monthly` ($5.99, 14-day free trial) and `workoutlogai_premium_annual` ($49.99, 14-day free trial)
- [ ] Optional: non-consumable `workoutlogai_premium_lifetime`
- [ ] Localize display names/descriptions; submit products for review with the app if required
- [ ] RevenueCat → add iOS app `com.acianfrocco.FitLog` + App Store Connect API key
- [ ] Import products; attach all to entitlement **`premium`**
- [ ] Offering **`default`** packages → set as **Current**
- [ ] Confirm Developer portal: App Group `group.com.acianfrocco.FitLog.shared` + HealthKit for App ID
- [ ] Archive Release build (Info.plist contains `appl_` key) → TestFlight
- [ ] Sandbox purchase → Restore → Manage Subscription
- [ ] Comp: promotional entitlement on App User ID → Restore / Refresh in app

## 4. Grant complimentary Premium access (secure)

This is the supported way to give specific users free Premium without exposing unlock logic in the app.

1. User opens **More → Subscription** and copies their **App User ID**.
2. In RevenueCat dashboard → **Customers**, search for that App User ID.
3. Grant a **Promotional Entitlement** for `premium` (duration: monthly, yearly, or lifetime).
4. User taps **Restore / Refresh access** in the app.

For Sign in with Apple users, the App User ID is their stable Apple credential user string after login.

## 5. Verify

- Free user: logging works; Coach tab shows Premium banner; AI calls blocked.
- Paid user: `EntitlementStore.isPremium == true`; AI + trends unlock.
- Comped user: promotional entitlement active after refresh.

## 6. Local StoreKit testing (simulator)

The repo includes `Configuration.storekit` at the project root with:

| Product ID | Type |
|---|---|
| `workoutlogai_premium_monthly` | Auto-renewable ($5.99/mo, 14-day trial) |
| `workoutlogai_premium_annual` | Auto-renewable ($49.99/yr, 14-day trial) |
| `workoutlogai_premium_lifetime` | Non-consumable |

The **FitLog** scheme references this file under **Run → Options → StoreKit Configuration**.

1. Open the FitLog scheme → **Run** → confirm **StoreKit Configuration** = `Configuration.storekit`.
2. Set a RevenueCat **sandbox** API key in `REVENUECAT_API_KEY` (or scheme env var).
3. Run on the simulator, open **More → Subscription → Upgrade**, and complete a test purchase.
4. Use **Restore / Refresh access** and **Manage Subscription** to verify post-purchase flows.

Logging and readiness remain free even when RevenueCat is unconfigured — the paywall purchase button stays disabled with an explanatory message.

## 7. App Store review notes

- Include "Not medical advice — general fitness coaching tool" near readiness and AI surfaces.
- Document HealthKit read usage (sleep, HRV, resting HR) in Privacy Nutrition Labels.
