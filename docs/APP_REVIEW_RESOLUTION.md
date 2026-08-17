# App Review resolution

## Guideline 5.1.1(v) — Account deletion (build 177)

Rejected example: **Workout Log AI 1.0 (177)**, 17 August 2026, iPhone 17 Pro Max. Submission ID `8a682dca-6425-42d9-82f8-d1e725e0ce88`.

Apple requires in-app account deletion because the app supports account creation (Sign in with Apple). Do **not** resubmit build **177**. Archive a **new** binary after this in-app Delete Account flow ships, attach IAPs to the version (see 2.1(b) below), Submit the app and subscriptions together, then reply in Resolution Center with a **physical-device** screen recording.

### In-app (this repo)

- Signed-in users: **More → Account → Delete Account**, and **More → Delete Account**.
- Confirmation alert, then permanent local deletion (SIWA identity, workouts, history, programs, Coach, readiness, body metrics, photos) and RevenueCat `logOut`. Rotating `backup_*.json` snapshots are removed so deleted data cannot be restored in-app. The app returns to the sign-in screen.
- Sign Out does **not** erase workouts. Delete Account does.
- Not a deactivate/disable flow. No email, phone, or customer-service step.
- App Store subscriptions stay with Apple (stated in the alert and privacy policy).
- Local-only users (Continue without signing in): **More → Erase all app data**.

### Screen recording for App Review (physical device)

Record on an iPhone (they used iPhone 17 Pro Max):

1. Launch Workout Log AI.
2. **Create a new account or sign in** with Sign in with Apple (there is no demo password).
3. Open **More**. Show **Delete Account** (Account section). Optional: open **Account** and show Delete Account there too.
4. Tap **Delete Account** → confirm **Delete Account** on the alert.
5. Show the app back on the sign-in screen.

Save as MP4. Attach it in the Resolution Center reply. Paste the same notes into App Review Information → **Notes** for future submissions.

### Resolution Center reply (paste)

```
Hello App Review,

Thank you for the Guideline 5.1.1(v) feedback on Workout Log AI 1.0 (177). We have added in-app account deletion and uploaded a new binary. Please do not review build 177.

Guideline 5.1.1(v)
Workout Log AI supports optional Sign in with Apple. Signed-in users can permanently delete their account in the app:

1. Sign in with Apple (or create a new account).
2. Open More → Delete Account (also More → Account → Delete Account).
3. Confirm the Delete Account alert.

This permanently deletes the in-app account and all locally stored user data, then returns to the sign-in screen. It is not a temporary deactivation. No website, email, or customer-service step is required.

Sign Out does not delete workout data. Delete Account does.

App Store subscriptions are billed by Apple and are not canceled by deleting the in-app account; users manage them in iOS Settings. That is stated in the confirmation alert and in the Privacy Policy.

Please see the attached screen recording captured on a physical device: Sign in with Apple → More → Delete Account → confirm → sign-in screen.

Thank you.
```

After merging to `main`, confirm GitHub Pages still serves the updated privacy policy (Delete Account path) at `https://cianfrocco4.github.io/FitLog/privacy-policy.html`.

---

## Guidelines 2.1(b) and 3.1.2(c) — IAP and subscription legal links (build 151)

Use this after a rejection that IAP products were not submitted, or that auto-renewable subscriptions are missing Terms of Use / Privacy Policy links.

Rejected example: **Workout Log AI 1.0 (151)**. Do **not** resubmit that binary. Archive a **new** build after the in-app changes on this branch, then complete every App Store Connect step below.

In-app code cannot attach IAP products or edit the App Description. Those steps are operator-only in [App Store Connect](https://appstoreconnect.apple.com).

## What Apple asked for

**2.1(b) App Completeness** — submit the In-App Purchase products with a new binary. Each auto-renewable SKU needs a Review Information screenshot.

**3.1.2(c) Subscriptions** — inside the app: functional Terms of Use (EULA) and Privacy Policy links, plus title, length, and price. In metadata: Privacy Policy URL in App Information, and the Terms of Use (EULA) URL in the App Description when using Apple’s standard EULA. Reply with a **screen recording** once that is done.

## In-app (already in this repo)

- Paywall uses StoreKit `SubscriptionStoreView` for monthly + annual (`workoutlogai_premium_monthly`, `workoutlogai_premium_annual`) with `.subscriptionStorePolicyDestination` for Privacy Policy and Terms of Use, plus Restore.
- Same two links: More → Subscription (Legal) and More → Legal & Support.
- Static title / duration / US list-price disclosure if StoreKit products fail to load (purchase stays disabled).
- Lifetime (`workoutlogai_premium_lifetime`) is **not** shown on the paywall. Only submit it if the product exists in ASC and you attach it to the version.

## App Store Connect — before Submit

### A. Paid Apps Agreement

Account → Agreements, Tax, and Banking → Paid Applications Agreement **Active**.

### B. Subscription products

Monetization → Subscriptions → group **Workout Log AI Premium**.

| Product ID | Type | Notes |
|------------|------|--------|
| `workoutlogai_premium_monthly` | Auto-renewable, 1 month | 14-day free trial |
| `workoutlogai_premium_annual` | Auto-renewable, 1 year | 14-day free trial |

For **each** SKU, status must leave **Missing Metadata**:

- [ ] Group App Store localization (display name)
- [ ] Product display name + description
- [ ] Pricing and availability
- [ ] **Review Information → Screenshot** of `SubscriptionStoreView` with title, duration, price, Restore, and legal links visible (same PNG is fine for every SKU). Capture steps: [SHIP_CHECKLIST.md](SHIP_CHECKLIST.md) §5a
- [ ] Optional review notes on the product: `Paywall: More → Subscription → Upgrade to Premium. Restore, Terms of Use, and Privacy Policy are on that screen.`

Do not leave lifetime in “referenced but not submitted” limbo. Either attach and screenshot it, or do not sell it (current paywall does not list it).

### C. Attach products to **this** version (this is the usual 2.1(b) miss)

App Store tab → the new iOS version → **In-App Purchases and Subscriptions** → **+** → add the subscription group / both auto-renewable products.

First subscription group **must** ship attached to a version.

### D. Metadata (3.1.2(c))

- [ ] App Information → **Privacy Policy URL:** `https://cianfrocco4.github.io/FitLog/privacy-policy.html`
- [ ] App Information → License: **Apple Standard EULA** (do not upload a custom EULA)
- [ ] Version **Description:** paste from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) — must include:

```
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://cianfrocco4.github.io/FitLog/privacy-policy.html
```

- [ ] Support URL: `https://cianfrocco4.github.io/FitLog/support.html`
- [ ] After merging to `main`, confirm GitHub Pages: privacy, support, and `terms-of-use.html` return HTTP 200

### E. New binary

- [ ] Archive **Release** (Xcode Cloud or Organizer). Do not reuse build **151**.
- [ ] Confirm `REVENUECAT_API_KEY` (`appl_…`) is in the shipping Info.plist
- [ ] RevenueCat: products synced, entitlement `premium`, offering `default` current
- [ ] Select the new build on the version page
- [ ] App Review Information → Notes: paste from [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md)

## Screen recording (required in the Resolution Center reply)

Record on iPhone (they also used iPad; iPhone is enough if the UI is the same):

1. Launch Workout Log AI (continue without signing in is fine).
2. Open **More → Subscription → Upgrade to Premium**.
3. Show `SubscriptionStoreView` with plan **titles**, **durations**, and **prices**.
4. Tap **Terms of Use** — Safari shows Apple’s Standard EULA.
5. Return to the app; tap **Privacy Policy** — Safari shows the hosted policy.
6. Point out **Restore purchases** on the paywall.
7. Optional: **More → Legal & Support** showing the same two links.

Save as MP4. Attach it to the Resolution Center reply. Also paste the reply text into App Review Information → Notes for future submissions.

## Resolution Center reply (paste)

```
Hello App Review,

Thank you for the 2.1(b) and 3.1.2(c) feedback on Workout Log AI 1.0 (151). We have addressed both issues and uploaded a new binary. Please do not review build 151.

Guideline 2.1(b)
- Auto-renewable In-App Purchases workoutlogai_premium_monthly and workoutlogai_premium_annual are submitted with this version.
- Each product has a Review Information screenshot of the in-app subscription UI.
- The subscription group is attached on the version’s In-App Purchases and Subscriptions section.

Guideline 3.1.2(c)
In the app (see attached screen recording):
- More → Subscription → Upgrade to Premium opens StoreKit SubscriptionStoreView with subscription title, length, and price.
- Functional Terms of Use (Apple Standard EULA) and Privacy Policy links are on the paywall, on More → Subscription, and under More → Legal & Support.
- Restore purchases is available on the paywall.

In App Store metadata:
- Privacy Policy URL: https://cianfrocco4.github.io/FitLog/privacy-policy.html
- Terms of Use (EULA) in the App Description: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
- License Agreement is Apple’s Standard EULA.

How to review subscriptions: More → Subscription → Upgrade to Premium. Sign in with Apple is optional.

Thank you.
```

## Verify before tapping Submit

- [ ] Both SKUs Ready to Submit / Waiting for Review (not Missing Metadata)
- [ ] Both SKUs listed on the version page
- [ ] Description contains `stdeula`
- [ ] Privacy Policy URL loads
- [ ] New build selected (not 151)
- [ ] Screen recording attached to the reply
- [ ] Device smoke test: [APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md) Premium / subscriptions section
