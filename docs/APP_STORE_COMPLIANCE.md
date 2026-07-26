# App Store Connect — Privacy, Compliance & Review Notes

Use this when filling out App Store Connect questionnaires for **Workout Log AI**.

---

## Privacy Nutrition Labels (detailed)

### Tracking
**Does this app track users?** → **No**

### Data collection summary

| Category | Collected | Linked to identity | Used for tracking | Purpose |
|----------|-----------|-------------------|-------------------|---------|
| Health & Fitness | Yes | Yes (on device) | No | App Functionality |
| Photos or Videos | Yes (optional) | Yes (on device) | No | App Functionality |
| User ID | Yes (optional, Sign in with Apple) | Yes | No | App Functionality |
| Purchases | Yes | Yes | No | App Functionality |
| Other Data (workout text for AI) | Yes (optional, Premium) | No | No | App Functionality |

### Health & Fitness — detail
- Workout sessions, sets, reps, weight (on device)
- **Readiness reads (optional):** sleep analysis, HRV (SDNN), resting heart rate — computed on device
- Apple Health workout write **only when user enables** sync

### Purchases — detail
- Auto-renewable subscriptions and optional lifetime unlock via RevenueCat / StoreKit
- Managed by Apple; restore available in-app

### Other Data (AI features) — detail
- Exercise names, muscle groups, program structure sent to proxy when Premium user invokes AI Coach or form guides
- Not linked to Apple ID or email in proxy requests

---

## Age rating (expected answers)

| Question | Answer |
|----------|--------|
| Unrestricted web access | No |
| User-generated content broadly shared | No |
| Made for Kids | No |
| Gambling | No |
| Violence | None |
| Mature/suggestive themes | None |

**Expected result:** 4+

---

## Export compliance

| Question | Answer |
|----------|--------|
| Is your app exempt from encryption registration? | Yes |
| Uses only standard HTTPS/TLS? | Yes |
| Info.plist flag | `ITSAppUsesNonExemptEncryption = false` |

In App Store Connect upload dialog: **No** for non-exempt encryption (or use exemption documentation).

---

## Sign in with Apple

- Sign in is **optional**
- No other third-party login providers
- Compliant with Apple guidelines for optional authentication

---

## HealthKit

Declared usage strings in Info.plist:
- **Read (readiness, user-initiated):** sleep analysis, heart rate variability (SDNN), resting heart rate
- **Write (optional sync):** completed workouts, distance, active energy, heart rate

Nutrition labels should document readiness reads separately from workout logging. All readiness scoring is on-device.

---

## Subscriptions (Guideline 3.1)

- **Free tier:** logging, rest timer, today's readiness score, basic history, widgets, custom exercises
- **Premium:** AI features, readiness trends, advanced analytics, unlimited history, export
- In-app paywall with restore purchases, Privacy Policy, and Apple Standard EULA links
- **Manage Subscription** in More → Subscription (active subscribers)
- Local testing: `Configuration.storekit` wired in the FitLog scheme

---

## App Review notes (paste into ASC)

```
Workout Log AI — Review Notes

AUTHENTICATION
Sign in with Apple is optional. Tap "Continue without signing in" to use the app locally.

CORE FUNCTIONALITY (works offline)
- Home → start a workout → log sets → finish workout
- History tab shows completed sessions (14-day range on free tier)
- Rest timer with local notifications and Live Activity

READINESS (free)
- Today's readiness score on Home; optional Connect Apple Health CTA
- Not medical advice — general fitness guidance only

PREMIUM / SUBSCRIPTIONS
- RevenueCat + StoreKit: monthly, annual (14-day trial), optional lifetime
- Public SDK key is in Info.plist (REVENUECAT_API_KEY, appl_…)
- Restore purchases on paywall and in More → Subscription
- Comp path: More → Subscription → copy App User ID → RevenueCat promotional entitlement → Restore / Refresh

OPTIONAL FEATURES
- HealthKit workout sync: More → Data & Integrations
- AI Coach / program builder / Daily Adjust / Week in review: Premium
- On Apple Intelligence devices (iOS 26+), short coaching may run on-device; otherwise cloud/heuristic fallbacks. Logging never depends on AI.

NO DEMO ACCOUNT REQUIRED.
```

---

## Review contact

| Field | Value |
|-------|--------|
| First name | Anthony |
| Last name | Cianfrocco |
| Phone | (your phone) |
| Email | acianfrocco@gmail.com |
