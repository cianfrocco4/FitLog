# RevenueCat setup (Workout Log AI)

Do this **in order**: App Store Connect products must exist before RevenueCat can import them. The app unlocks Premium when RevenueCat reports entitlement **`premium`** as active. The paywall loads whatever offering is marked **Current** (`offerings.current`).

## Constants (must match code)

| Thing | Exact value |
|---|---|
| Bundle ID | `com.acianfrocco.FitLog` |
| Entitlement | `premium` |
| Offering identifier | `default` (and set as **Current**) |
| Monthly product | `workoutlogai_premium_monthly` — $5.99/mo, 14-day trial |
| Annual product | `workoutlogai_premium_annual` — $49.99/yr, 14-day trial |
| Lifetime (optional) | `workoutlogai_premium_lifetime` — non-consumable |

Source of truth in code: `FitLog/Features/Subscription/Models/RevenueCatConfig.swift`.

The **public** SDK key (`appl_…`) lives in `FitLog/Info.plist` under `REVENUECAT_API_KEY`. You may override via Xcode scheme env var `REVENUECAT_API_KEY` for local experiments. Do **not** put the RevenueCat **secret** API key in the app.

---

## Operator checklist

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
- [ ] Confirm Info.plist `appl_` key matches **this** RevenueCat project
- [ ] Archive Release build → TestFlight
- [ ] Sandbox purchase → Restore → Manage Subscription
- [ ] Comp: promotional entitlement on App User ID → Restore / Refresh in app

---

## Part A — App Store Connect (do first)

### A1. Finish agreements (blocks everything if incomplete)

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Business** (or **Agreements, Tax, and Banking**).
2. Accept the **Paid Applications** agreement if it’s pending.
3. Complete **Banking** and **Tax** forms until status is Active.
4. Without this, subscriptions won’t sell in sandbox or production.

### A2. Create a Sandbox tester

You do **not** create this at [appleid.apple.com](https://appleid.apple.com). Sandbox Apple Accounts are created **only** inside App Store Connect. They exist for testing In-App Purchases / subscriptions and are separate from your real personal Apple Account.

Official Apple help: [Create a Sandbox Apple Account](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/create-a-sandbox-apple-account/).

#### Pick an email that has never been an Apple Account

- The email **must not** already be registered as an Apple Account (or used for iTunes / App Store purchases).
- Do **not** use your real `icloud.com` / personal Apple ID email.
- Good options:
  - A brand-new unused address (e.g. a free Gmail you create only for this).
  - A plus-alias on a mailbox you control **only if** that exact address is not already an Apple Account (e.g. `you+fitlog-sandbox@gmail.com`). If Apple rejects it as “already in use,” pick another unused address.
- You’ll need to be able to receive mail at that address if Apple sends verification.

#### Create the Sandbox account in App Store Connect

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) with your **paid** Apple Developer Program account (Account Holder / Admin / App Manager as needed).
2. Top nav → **Users and Access**.
3. Top of that page → **Sandbox** (sometimes labeled under Sandbox → **Testers**).
4. Click **+** (or **Create Test Accounts** the first time).
5. Fill in:
   - **First name / Last name** — anything (e.g. `Sandbox` / `Tester`).
   - **Email** — the unused address from above.
   - **Password** — choose a strong password (Apple shows requirements as you type). **Save this password** somewhere safe; you’ll use it on the device.
   - **Country or Region** — e.g. **United States** (this picks the App Store storefront for pricing / products).
6. Click **Create**.

That’s it for “creating the Apple ID.” App Store Connect registers it as a **Sandbox Apple Account**. You should see it listed under Sandbox testers.

#### Sign in on a physical device (for IAP / subscription testing)

For **In-App Purchase** sandbox testing you normally keep your **real** iCloud / device Apple Account signed in. You only sign into Sandbox in the developer sandbox slot:

1. Enable **Developer Mode** on the device if needed: **Settings → Privacy & Security → Developer Mode** (required for running development-signed builds from Xcode).
2. Install a **development-signed** build (Run from Xcode) or a TestFlight build.
3. Preferred (IAP): **Settings → Developer → Sandbox Apple Account** → sign in with the sandbox email + password you created.  
   - The **Developer** menu often appears after you’ve attempted a purchase once in a development-signed app, or after Developer Mode is on.
4. Open Workout Log AI → **More → Subscription → Upgrade** and complete a purchase. The StoreKit sheet should show sandbox behavior (and often **[Environment: Sandbox]** in the confirmation UI).
5. When finished testing, sign out of the Sandbox Apple Account in **Settings → Developer** so you don’t confuse future purchases.

**Do not** replace your main device Apple Account with the sandbox account just to test IAP — that is the old / Apple Pay-style path and can mess up your personal device. Use **Settings → Developer → Sandbox Apple Account** instead.

#### When you need a Sandbox account vs when you don’t

| Environment | Need Sandbox Apple Account? |
|---|---|
| Simulator + `Configuration.storekit` (scheme StoreKit Configuration) | **No** — local StoreKit file is enough for UI / purchase flow smoke |
| Device, Xcode debug build, real ASC products | **Yes** |
| TestFlight build | **Yes** (sandbox purchases; use Sandbox account when prompted / in Developer settings) |

#### Common A2 failures

| Problem | Fix |
|---|---|
| “Email already in use” / can’t create tester | That address is already an Apple Account — use a never-used email |
| No **Developer** → **Sandbox Apple Account** on device | Enable Developer Mode; run a development build; attempt a purchase once so the Sandbox row appears |
| Charged real money / production App Store | You signed into Media & Purchases / App Store with a real account instead of Sandbox — sign out of Sandbox slot and re-check Settings → Developer |
| Purchase fails immediately | Finish **A1** (Paid Apps Agreement); confirm subscription products exist (A4–A6) |

### A3. Open your app’s Monetization

1. **Apps** → **Workout Log AI** (or create the app record if it doesn’t exist yet — name **Workout Log AI**, bundle `com.acianfrocco.FitLog`).
2. Left sidebar → **Monetization** → **Subscriptions**.

### A4. Create the subscription group

1. Click **Create** (or **+**).
2. **Reference Name:** `Workout Log AI Premium`  
   (Internal only; users don’t see this as the product name.)
3. Create the group.

### A5. Create the monthly subscription

1. Inside that group → **Create Subscription** (or **+**).
2. Fill in:

| Field | What to enter |
|---|---|
| Reference Name | `Premium Monthly` (internal) |
| Product ID | `workoutlogai_premium_monthly` — **exact**, cannot change later |
| Subscription Duration | **1 Month** |

3. **Subscription Prices** → add USA (or your territories) → **$5.99**.
4. **Introductory Offers** → add:
   - Type: **Free**
   - Duration: **1 Week** × 2, or **2 Weeks** if available — goal is **14 days free**
   - Eligibility: new subscribers (default is fine)
5. **Localization** (at least English US):
   - Display Name: e.g. `Premium Monthly`
   - Description: e.g. `AI coach, readiness trends, unlimited history, and export.`
6. Save. Status may show **Missing Metadata** / **Ready to Submit** until the app version is submitted with it — that is normal for now.

### A6. Create the annual subscription

Same as monthly, but:

| Field | Value |
|---|---|
| Reference Name | `Premium Annual` |
| Product ID | `workoutlogai_premium_annual` |
| Duration | **1 Year** |
| Price | **$49.99** |
| Intro offer | 14-day free trial |
| Localization | `Premium Annual` + short description |

### A7. Optional lifetime (non-subscription)

1. **Monetization** → **In-App Purchases** (not Subscriptions).
2. **+** → **Non-Consumable**.
3. Product ID: `workoutlogai_premium_lifetime`.
4. Price: e.g. **$99.99**.
5. Localization: `Premium Lifetime` / description.
6. Optional for Phase 1; monthly + annual are enough to ship.

### A8. Review levels in the subscription group

In the subscription group, set **Subscription Levels** so annual is a higher level than monthly if you want upgrade/downgrade behavior Apple expects (typical: annual = level 1, monthly = level 2). Exact ranking is a product choice; just don’t leave levels conflicting.

---

## Part B — RevenueCat dashboard

### B1. Create project + app

1. Go to [RevenueCat](https://app.revenuecat.com/) → sign in → **Create new project** (or open existing).
2. **Project settings → Apps** → **+ New**.
3. Platform: **iOS**.
4. Bundle ID: `com.acianfrocco.FitLog` — must match exactly.
5. Copy the **Public API key** that starts with `appl_`.
   - The repo already has one in Info.plist. If RevenueCat shows a **different** `appl_` key for this project, update Info.plist to match **this** project’s key (or the app will talk to the wrong RC project).

### B2. Connect App Store Connect to RevenueCat

RevenueCat needs an App Store Connect API key to import products:

1. In App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API** → **Keys** → **+**.
2. Name: e.g. `RevenueCat`.
3. Access: **App Manager** or **Admin** (needs access that can read IAPs).
4. Download the `.p8` once; note **Issuer ID** and **Key ID**.
5. In RevenueCat → your iOS app → **App Store Connect API** / **Service credentials** → paste Issuer ID, Key ID, upload `.p8`.
6. Save / connect.

### B3. Create entitlement `premium`

An **entitlement** is RevenueCat’s name for an access level in your app (“user has Premium”). It is **not** an App Store product and **not** a price. Store products (monthly/annual) unlock the entitlement when purchased; the app only checks whether `premium` is active.

Workout Log AI uses **one** entitlement for everything gated behind Premium (AI Coach, longer history, readiness trends, export, etc.). Do **not** create separate entitlements per feature unless you later add paid tiers.

Official docs: [Entitlements](https://www.revenuecat.com/docs/getting-started/entitlements).

#### Why the identifier must be exactly `premium`

The app looks up this string in customer info:

```swift
// RevenueCatConfig.swift
static let premiumEntitlementID = "premium"

// PurchaseService / EntitlementStore
customerInfo.entitlements["premium"]?.isActive == true
```

If you create `Premium`, `pro`, or `workoutlogai_premium` in the dashboard, purchases can succeed in the App Store but the app will still treat the user as free.

| Field | Enter exactly | Notes |
|---|---|---|
| Identifier | `premium` | Lowercase, no spaces. This is the API key the SDK reads. |
| Display name / Description | `Premium` (or “Workout Log AI Premium”) | Cosmetic only — dashboard / human-readable. Does **not** need to match code. |

#### Click path in the RevenueCat dashboard

1. Open [app.revenuecat.com](https://app.revenuecat.com/) and select the **same project** you created in B1 (bundle `com.acianfrocco.FitLog`).
2. Left sidebar → **Product catalog** → **Entitlements**.
3. Click **+ New** / **New entitlement** (top right).
4. In the create form:
   - **Identifier:** type `premium` — copy/paste to avoid typos. Do not capitalize.
   - **Description** (if shown): e.g. `Full Premium access — AI, trends, unlimited history, export`.
5. Save / **Create**.
6. You should land on (or see in the list) an entitlement row with identifier **`premium`**. Open it to confirm the identifier in the detail header matches exactly.

#### What to do on this screen (and what to skip for now)

- **Creating** the entitlement is enough for B3. You can leave **Associated products** empty until B4.
- After B4 imports products, come back here (or attach from the product side) and link:
  - `workoutlogai_premium_monthly`
  - `workoutlogai_premium_annual`
  - optional `workoutlogai_premium_lifetime`
- Until products are attached, a real purchase may complete in StoreKit/App Store but RevenueCat will **not** flip `premium` to active — the app stays free. Attachment is required (covered in B4).

#### How you’ll know B3 is done

| Check | Expected |
|---|---|
| Entitlements list | One row with identifier `premium` |
| No duplicate tiers | You did **not** also create `pro`, `ai`, etc. for Phase 1 |
| Code match | Dashboard identifier == `RevenueCatConfig.premiumEntitlementID` (`premium`) |

#### Common B3 mistakes

| Mistake | Result | Fix |
|---|---|---|
| Identifier `Premium` or `PREMIUM` | SDK lookup for `"premium"` fails → always free | Delete/recreate as `premium`, or rename if the UI allows editing the identifier |
| Identifier `workoutlogai_premium` (product ID) | Same — app never sees active entitlement | Use `premium`; product IDs belong on **Products**, not Entitlements |
| Multiple entitlements (`ai`, `history`, …) | App only checks `premium`; other entitlements are ignored | Attach all products to the single `premium` entitlement |
| Wrong RevenueCat project | Info.plist `appl_` key points elsewhere | Create `premium` in the project that owns your `appl_` key |

### B4. Import / add products

A **product** in RevenueCat is a pointer to an App Store Connect product ID. RevenueCat does not create App Store prices — those must already exist from Part A (`workoutlogai_premium_monthly`, etc.). B4’s job is: (1) register those IDs in RevenueCat under your **iOS** app, then (2) attach each one to entitlement **`premium`**.

Flow after this works:

```
User buys App Store product
  → RevenueCat sees that product ID
  → Grants entitlement "premium"
  → App checks entitlements["premium"]?.isActive
```

Official docs: [Configuring Products](https://www.revenuecat.com/docs/projects/configuring-products).

#### Prerequisites (do these first)

- [ ] Part A: ASC subscription products exist with the **exact** product IDs below (product IDs cannot be changed after creation in ASC).
- [ ] B1: iOS app `com.acianfrocco.FitLog` exists in this RevenueCat project.
- [ ] B2: App Store Connect API key connected (needed for **Import**; manual add can work without it but import is preferred).
- [ ] B3: Entitlement `premium` exists.

#### Exact product IDs (copy/paste)

| App Store Connect product ID | Type | Required for Phase 1? |
|---|---|---|
| `workoutlogai_premium_monthly` | Auto-renewable subscription | Yes |
| `workoutlogai_premium_annual` | Auto-renewable subscription | Yes |
| `workoutlogai_premium_lifetime` | Non-consumable | Optional |

IDs are case-sensitive and must match ASC **character-for-character**. A typo here is the #1 cause of “purchase works but app stays free” or empty offerings later.

#### Prefer: Import from App Store Connect

1. Open your RevenueCat project → left sidebar **Product catalog** → **Products**.
2. Select the tab for your **iOS / App Store** app (not **Test Store**).  
   - **Test Store** is RevenueCat’s built-in fake store for quick SDK demos. Phase 1 shipping / TestFlight / device sandbox needs the **real App Store** products.
3. Click **+ New** (or the dropdown) → choose **Import** / **Import products** if available.
4. RevenueCat lists products it can see from ASC via the API key from B2.
5. Select:
   - `workoutlogai_premium_monthly`
   - `workoutlogai_premium_annual`
   - and lifetime if you created it
6. Confirm / import. They should appear in the Products list under the iOS app.

If the import list is empty or missing products:

- Wait 5–15 minutes after creating products in ASC, then retry import.
- Confirm B2 credentials (Issuer ID, Key ID, `.p8`) and that the key has **App Manager** (or Admin) access.
- Confirm you’re in the correct ASC team / app and the product IDs were saved (not abandoned drafts).
- Confirm you’re importing under the iOS app whose bundle ID is `com.acianfrocco.FitLog`.

#### Fallback: Add products manually

Use this if import still fails but the ASC products definitely exist.

1. **Product catalog** → **Products** → iOS app tab → **+ New**.
2. Choose the **App Store / iOS** app (again: not Test Store).
3. For each product, set the **Product identifier** to the ASC product ID **exactly** (e.g. `workoutlogai_premium_monthly`).
4. Display name (if asked) can be human-readable: `Premium Monthly` — this is cosmetic in RC.
5. Save. Repeat for annual (+ lifetime if needed).

Manual add only registers the ID in RevenueCat. The store must still have that product; otherwise device purchases / offering packages will fail to load store metadata.

#### Attach every product to entitlement `premium` (required)

Creating/importing products is not enough. Until attachment, RevenueCat will not grant Premium when those products are purchased.

**Option A — from the entitlement (recommended):**

1. **Product catalog** → **Entitlements** → open **`premium`**.
2. In **Products** / **Associated products**, click **Attach**.
3. Select **all** of: monthly, annual, (optional lifetime).
4. Save.

**Option B — from each product:**

1. **Products** → open `workoutlogai_premium_monthly`.
2. Attach / link to entitlement **`premium`**.
3. Repeat for annual (and lifetime).

Either path is fine; end state must be: every paid product unlocks the same `premium` entitlement.

#### How you’ll know B4 is done

| Check | Expected |
|---|---|
| Products list (iOS app) | `workoutlogai_premium_monthly` and `_annual` present (IDs exact) |
| Entitlement `premium` detail | Those products listed under Associated / Attached products |
| No orphan products | You did not leave monthly/annual attached to a different entitlement |
| Not only Test Store | Products exist on the **App Store** app tab for shipping / TestFlight |

You have **not** finished monetization setup until B5 (offering `default` marked **Current**). Products + entitlement alone do not populate the paywall packages.

#### “Missing Metadata” on products in RevenueCat

This is almost always **App Store Connect’s status** mirrored into RevenueCat — not a bad import, and not something you fix inside RevenueCat’s product form.

Open [App Store Connect](https://appstoreconnect.apple.com) → your app → **Monetization** → **Subscriptions** → open each product (and the subscription **group**). Complete everything Apple requires until status becomes **Ready to Submit** (or later **Waiting for Review** / **Approved**).

Checklist (most common gaps first):

1. **Review screenshot** (very often the only missing piece)  
   - On the subscription → **Review Information** → upload a screenshot of your paywall / subscription UI.  
   - For Apple Review only; use a real phone-sized screenshot of **More → Subscription → Upgrade** (or a simulator capture at an accepted iPhone size).  
   - Specs: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications).
2. **Subscription localization** — at least one language (e.g. English U.S.) with **Display Name** + **Description**.
3. **Subscription group localization** — open the group **Workout Log AI Premium** → add a **App Store Localization** (group display name). Easy to miss; status stays Missing Metadata without it.
4. **Price** — at least one territory (e.g. United States @ $5.99 / $49.99).
5. **Introductory offer** (if you added a trial) — fully configured, not half-filled.
6. **Paid Apps Agreement** — A1 still Active (tax/banking).

After saving in ASC, wait a few minutes and refresh RevenueCat (or re-sync). The warning should clear once ASC no longer reports Missing Metadata.

**Can you keep going?** Yes — finish B5 (offering). Sandbox / StoreKit testing may still work while ASC shows Missing Metadata, but clear it before App Review / production; incomplete metadata can block store serving and submission.

#### Common B4 failures

| Problem | Fix |
|---|---|
| Import shows no products | Finish Part A; wait; recheck B2 API key; retry import |
| Product ID mismatch (`workout_log_…` vs `workoutlogai_…`) | Delete wrong RC product; re-add with exact ASC ID |
| Products only on Test Store tab | Add/import again under the **iOS App Store** app |
| **Missing Metadata** warning on RC products | Complete ASC fields above (screenshot + group localization are the usual culprits) |
| Purchase succeeds, app stays free | Product not attached to entitlement `premium` |
| Attached to `Premium` / wrong entitlement | Detach and attach to identifier **`premium`** (B3) |
| Lifetime missing | Optional — skip unless you created the non-consumable in A7 |

### B5. Create offering `default` and make it Current

1. **Product catalog** → **Offerings** → **+ New**.
2. Identifier: **`default`** (exact).
3. Add packages:
   - Package type **Monthly** → product `workoutlogai_premium_monthly`
   - Package type **Annual** → product `workoutlogai_premium_annual`
   - Optional: **Lifetime** → `workoutlogai_premium_lifetime`
4. **Very important:** set this offering as **Current** (toggle / “Make current”).  
   The app uses `offerings.current` — if nothing is Current, the paywall shows empty / purchases unavailable.

### B6. Sanity check in RevenueCat

You should see:

```
Entitlement: premium
  ← workoutlogai_premium_monthly
  ← workoutlogai_premium_annual
  ← workoutlogai_premium_lifetime (optional)

Offering: default [Current]
  ← $rc_monthly → monthly product
  ← $rc_annual → annual product
```

---

## Part C — Confirm the app side

Part C is a **local Xcode checklist** before you run purchase tests (Part D). You are verifying three things:

1. The app loads the **correct RevenueCat public API key** for the project you configured in Part B.
2. The **FitLog** run scheme uses `Configuration.storekit` for simulator / local StoreKit testing.
3. You have **not** put a RevenueCat **secret** key (or App Store Connect `.p8`) into the iOS target.

No dashboard clicking is required here if Parts A–B are done — this is “does the binary talk to the right place?”

### C1. Confirm the public API key in the app

The SDK reads the key via `RevenueCatConfig.apiKey` in this order:

1. Process environment variable `REVENUECAT_API_KEY` (scheme / launch env), if non-empty.
2. Else `FitLog/Info.plist` key `REVENUECAT_API_KEY`.

#### Find the key in RevenueCat

1. [app.revenuecat.com](https://app.revenuecat.com/) → the project used in B1.
2. **Project settings** → **API keys** (or open the **iOS app** → API keys).
3. Copy the **Apple / public** SDK key. It must start with **`appl_`**.

#### Confirm it matches the repo

1. In Xcode, open `FitLog/Info.plist`.
2. Find **`REVENUECAT_API_KEY`**.
3. Compare to the RevenueCat dashboard value **character-for-character**.
4. If they differ (you created a new RC project, rotated keys, etc.):
   - Update the plist string to the dashboard `appl_…` key.
   - Clean build folder (Product → Clean Build Folder) and run again so the new value is embedded.

#### Public vs secret (do not mix these up)

| Key type | Looks like | Where it belongs |
|---|---|---|
| **Public SDK key** | `appl_…` | ✅ `Info.plist` / optional scheme env — **this is what the app uses** |
| **Secret API key** | `sk_…` | ❌ Never in the iOS app. Server / RC dashboard / CI only |
| **App Store Connect API `.p8`** | file from ASC | ❌ Only in RevenueCat (B2) / your password manager — never in the app target |

If the public key is missing or empty, `EntitlementStore.configureIfNeeded()` skips `Purchases.configure`, Premium stays locked, and the paywall explains that purchases are unavailable. Logging and readiness still work.

### C2. Confirm StoreKit Configuration on the FitLog scheme

The shared scheme should already point at the project-root file `Configuration.storekit` (product IDs match ASC / RC). Verify in Xcode:

1. Xcode toolbar → scheme dropdown → **FitLog** (not FitLogWidgets / tests).
2. Scheme dropdown → **Edit Scheme…** (or Product → Scheme → Edit Scheme).
3. Left column → **Run**.
4. Top tabs → **Options**.
5. **StoreKit Configuration** should be **`Configuration.storekit`** (or the path to that file).
   - If it says **None**, click the menu → choose `Configuration.storekit` from the project.
6. Left column → **Run** → **Arguments** (optional check):
   - You do **not** need a `REVENUECAT_API_KEY` env var if Info.plist already has the correct `appl_` key.
   - Only add a scheme env `REVENUECAT_API_KEY` = `appl_…` if you want to override the plist for a temporary experiment (env wins over plist).
7. Click **Close**.

**What StoreKit Configuration does**

- When set, **Run** from Xcode (simulator or device) uses the local `.storekit` catalog for IAP sheets instead of (or in addition to) the live App Store sandbox catalog — ideal for fast UI testing in **D1**.
- **TestFlight / App Store** builds ignore this scheme option; they use real ASC products + sandbox/production StoreKit (**D2**).

### C3. Confirm SPM / SDK is linked (sanity)

1. Xcode → project navigator → **FitLog** project → **Package Dependencies**.
2. You should see **`purchases-ios-spm`** (RevenueCat).
3. Target **FitLog** → **General** / **Frameworks** should include the RevenueCat product used by the app.

If the package is missing, resolve packages (File → Packages → Resolve Package Versions) and rebuild. Without the SDK, `#if canImport(RevenueCat)` paths are off and Premium never configures.

### C4. Quick in-app smoke (before full Part D purchases)

1. Product → **Run** on a simulator with scheme **FitLog**.
2. Open **More → Subscription**.
3. You should see Premium status (**Free** or **Active**) and an **App User ID** (after configure) once RevenueCat initializes.
4. Tap **Upgrade to Premium** — paywall should open.
   - If offerings loaded (B5 Current offering + key match): packages appear.
   - If key missing: purchase disabled / unavailable message.
   - If key OK but offering not Current / products incomplete: empty or unavailable packages — go back to B4–B5.

You do not need a successful purchase to finish Part C; you only need key + StoreKit scheme + paywall reachable.

### C5. Release / TestFlight reminder (for later)

When you archive for TestFlight:

1. Archive uses **Release** configuration and embeds `Info.plist` — the `appl_` key in plist **must** be present (scheme env vars from Run do **not** apply to archives).
2. Leave StoreKit Configuration as-is for local Run; it does not affect the uploaded IPA.
3. Never paste `sk_…` into Release Info.plist “to make production work” — that is wrong and unsafe.

### How you’ll know Part C is done

| Check | Expected |
|---|---|
| Info.plist `REVENUECAT_API_KEY` | Starts with `appl_` and matches **this** RC project |
| No secret in app | No `sk_…`, no ASC `.p8` in the FitLog target |
| FitLog scheme → Run → Options | StoreKit Configuration = `Configuration.storekit` |
| Run app → More → Subscription | Screen loads; App User ID appears when configured |
| Upgrade | Paywall opens (packages depend on B5) |

### Common Part C failures

| Problem | Fix |
|---|---|
| Paywall “purchases unavailable” / never configures | Empty or missing `REVENUECAT_API_KEY` in plist (and no scheme override) |
| Offerings empty / wrong project | `appl_` key from a different RC project — paste the key from the project where you created `premium` + products |
| StoreKit sheet shows wrong / no products locally | Scheme StoreKit Configuration is **None** — set `Configuration.storekit` |
| Works in Run, fails in TestFlight | Archive doesn’t get scheme env overrides — put `appl_` in Info.plist |
| Accidentally used secret key | Remove `sk_…` from the app; use only `appl_…` |

---

## Part D — How to test

### D1. Simulator + StoreKit config (fast UI test)

The repo includes `Configuration.storekit` at the project root with:

| Product ID | Type |
|---|---|
| `workoutlogai_premium_monthly` | Auto-renewable ($5.99/mo, 14-day trial) |
| `workoutlogai_premium_annual` | Auto-renewable ($49.99/yr, 14-day trial) |
| `workoutlogai_premium_lifetime` | Non-consumable |

1. Open the FitLog scheme → **Run** → confirm **StoreKit Configuration** = `Configuration.storekit`.
2. Run on the simulator, open **More → Subscription → Upgrade**, and complete a test purchase.
3. Confirm Premium unlocks (Coach sends, History longer ranges, trends).
4. Use **Restore / Refresh access** and **Manage Subscription** (manage may be limited on simulator).

If packages don’t load: RevenueCat can’t see products yet, or offering isn’t Current, or API key doesn’t match the project.

Logging and readiness remain free even when RevenueCat is unconfigured — the paywall purchase button stays disabled with an explanatory message.

### D2. Device / TestFlight (real sandbox)

1. Archive **Release**, upload to TestFlight, install.
2. On device, sign in with the **Sandbox** Apple ID when StoreKit prompts (not your production Apple ID).
3. Purchase monthly/annual → confirm unlock.
4. Delete/reinstall → **Restore purchases** → still Premium.
5. More → Subscription → copy **App User ID**.

### D3. Complimentary (comp) access

Use this to give **specific people** free Premium (beta testers, yourself, support comps) **without** shipping a secret unlock code in the app. Comp access is a **RevenueCat promotional entitlement** on entitlement identifier **`premium`**. It does not create an App Store subscription, does not charge the user, and does not appear in App Store Connect as a purchase.

Official docs: [Customer Profile — Granted Entitlements](https://www.revenuecat.com/docs/dashboard-and-metrics/customer-profile), [Supporting Customers](https://www.revenuecat.com/docs/dashboard-and-metrics/supporting-your-customers).

#### How App User ID works in Workout Log AI

| User mode | What shows as App User ID | Stable across reinstall? |
|---|---|---|
| **Sign in with Apple** | Apple’s stable credential user string (app calls `Purchases.logIn` with it) | **Yes** — prefer this for comps |
| **Local-only / not signed in** | RevenueCat anonymous ID (often looks like `$RCAnonymousID:…`) | **No** — new install can get a new ID; old promo is orphaned |

In the app: **More → Subscription** → **Support access** section → **App User ID** + **Copy App User ID**.

If the user is local-only, the orange caption asks them to Sign in with Apple for a stable ID — do that **before** you grant the promo when possible.

#### End-to-end: user side then you (operator)

**User (or you testing on your device):**

1. Install / run the app (simulator, device, or TestFlight).
2. Preferably: Sign in with Apple.
3. Open **More → Subscription**.
4. Confirm RevenueCat is configured (App User ID is visible). If the ID is missing, Part C key / configure failed — fix that first.
5. Tap **Copy App User ID** and send it to you (Messages, email, etc.).
6. Wait for you to grant in the dashboard, then tap **Restore / Refresh access**.
7. Premium row should show **Active**; AI / trends / longer history unlock.

**You (RevenueCat dashboard):**

1. Open [app.revenuecat.com](https://app.revenuecat.com/) → the **same project** whose `appl_` key is in Info.plist.
2. Left sidebar → **Customers** (sometimes under Customer lists / Customer support).
3. Paste the **exact** App User ID into search and open that customer.  
   - Search is exact-match style — no fuzzy email lookup unless you later attach subscriber attributes.
   - If the customer is not found: they have never launched a build that called `Purchases.configure` with this project’s key, or they copied the wrong ID / wrong project.
4. On the customer profile, find the **Entitlements** card (often right column).
5. Click **Grant** (or **Grant promotional entitlement**).
6. In the grant dialog:
   - **Entitlement:** choose **`premium`** (must match B3 — not a product ID).
   - **Duration:** pick a preset (e.g. weekly, monthly, yearly, lifetime) or a custom end date / “until” date.
   - For permanent staff/self comps, **lifetime** is simplest; for beta windows, use a fixed end date.
7. Confirm **Grant**. Access is active on RevenueCat’s side immediately. Granted entitlements often show with an `rc_promo` prefix in the customer timeline.
8. Tell the user to tap **Restore / Refresh access** (or force-quit and reopen so `CustomerInfo` refreshes). The SDK does not always push the promo to the UI until refresh.

#### Verify the grant worked

| Check | Expected |
|---|---|
| RC customer → Entitlements | `premium` active (promotional / `rc_promo`) |
| App → More → Subscription | **Premium: Active** after Restore / Refresh |
| App behavior | Coach / trends / history beyond free limits unlock |
| App Store subscriptions | No new ASC subscription required — Manage Subscription may still show nothing paid |

#### Revoke or shorten a comp

1. Same customer profile → Entitlements card.
2. Use the menu (**…**) on the granted promotional entitlement → **Revoke** / remove.
3. User taps **Restore / Refresh access** (or relaunches) → Premium becomes **Free** again after the client refreshes.

Granted access also expires automatically when the duration / end date you chose is reached.

#### Important behaviors / limits

- **Wrong project:** Granting `premium` in Project A while the app’s `appl_` key points at Project B does nothing visible in the app.
- **Wrong App User ID:** Granting on an old anonymous ID after the user reinstalled local-only mode leaves them free. Have them Sign in with Apple, copy the **new** ID, grant again.
- **Not an App Store promo code:** This is not Offer Codes / subscription offer codes in ASC. Those are a separate Apple feature.
- **Sandbox vs production:** Promotional entitlements work for both; RevenueCat treats the promo grant as a production-style promotional transaction in its systems, but the user still is not charged.
- **Security:** App User IDs are OK to show in Support (as this app does). Do not invent a client-side “comp password.” Anyone who can guess sequential IDs would be a risk — RC anonymous / Apple IDs are not sequential counters you control.
- **Bulk comps:** For many users, use RevenueCat’s REST API grant endpoint with the **secret** API key on a server — never from the iOS app. Dashboard Grant is right for one-off / small numbers.

#### Operator script (copy/paste for support)

> 1. Open Workout Log AI → More → Subscription.  
> 2. Sign in with Apple if you haven’t (recommended).  
> 3. Tap **Copy App User ID** and send it to me.  
> 4. After I confirm, tap **Restore / Refresh access**.  
> 5. Premium should show **Active**.

#### Common D3 failures

| Problem | Fix |
|---|---|
| Customer not found in RC | User must open the app once with the correct `appl_` key; copy ID again from **this** install |
| Granted but app still Free | User must **Restore / Refresh**; confirm entitlement identifier is `premium`; confirm same RC project |
| Worked, then lost after reinstall | They were on anonymous ID — Sign in with Apple and re-grant on the stable ID |
| Granted wrong entitlement name | Revoke; grant on identifier **`premium`** only |
| Looking for user by email | RC search needs App User ID unless you add email as a subscriber attribute later |

---

## Part E — What “done” looks like

| Check | Pass criteria |
|---|---|
| ASC products | Monthly + annual exist with exact product IDs |
| RC entitlement | `premium` attached to those products |
| RC offering | `default` is **Current** with monthly + annual packages |
| App key | `appl_` in Info.plist matches this RC project |
| Free user | Logging/readiness work; Coach blocked; paywall opens |
| Paid sandbox | Purchase → AI + trends + history unlock (`EntitlementStore.isPremium == true`) |
| Comp | Promo entitlement → refresh → unlock |

---

## Common failures

| Symptom | Fix |
|---|---|
| Paywall “Purchases unavailable” / empty packages | Offering not **Current**, products not attached, or wrong `appl_` key |
| Products missing in RevenueCat | ASC products not created / API key not connected / wait & re-import |
| Sandbox purchase fails | Paid Apps Agreement incomplete, or using real Apple ID instead of Sandbox |
| Purchase succeeds but app stays free | Product not attached to entitlement `premium` |
| Works in simulator StoreKit, not on device | Device needs real ASC products + RC sync + sandbox account |
| Canceled subscription still shows Premium Active | **Expected** until the paid period ends — cancel turns off auto-renew; `isActive` stays true until `expirationDate`. Subscription screen should show **Active (canceled)** + access-until date after refresh. Sandbox periods are shortened (minutes), then status becomes Free. |

---

## Suggested session plan (one sitting)

1. (~15 min) Agreements + Sandbox tester
2. (~30 min) Subscription group + monthly + annual + trials + localizations
3. (~20 min) RevenueCat app + ASC API key + entitlement + products + Current offering
4. (~20 min) Simulator StoreKit purchase smoke
5. Later: TestFlight sandbox purchase + restore + one comp grant

---

## App Store review notes

- Include “Not medical advice — general fitness coaching tool” near readiness and AI surfaces.
- Document HealthKit read usage (sleep, HRV, resting HR) in Privacy Nutrition Labels.
