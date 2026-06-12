# App Store Connect — Privacy, Compliance & Review Notes

Use this when filling out App Store Connect questionnaires for **The Workout Log** v1.0.

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
| Other Data (workout text for AI) | Yes (optional) | No | No | App Functionality |

### Health & Fitness — detail
- Workout sessions, sets, reps, weight
- Stored **on device**; not uploaded to your servers
- Apple Health read/write **only when user enables** sync

### Photos — detail
- Progress photos user selects
- Stored **locally** on device

### User ID — detail
- Sign in with Apple anonymous identifier
- Optional; app works without sign-in

### Other Data (AI features) — detail
- Exercise names, muscle groups, program structure sent to proxy when user invokes AI Coach or form guides
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
- **Read:** workouts, body mass, heart rate, related fitness data
- **Write:** completed workouts, distance, active energy, heart rate

Nutrition labels should match: Health & Fitness data, user-controlled via Settings.

---

## App Review notes (paste into ASC)

```
The Workout Log — Review Notes (v1.0)

AUTHENTICATION
Sign in with Apple is optional. On first launch, tap "Continue without signing in"
to use the app locally without an account.

CORE FUNCTIONALITY (works offline)
- Home → start a workout → log sets → finish workout
- History tab shows completed sessions
- Rest timer with local notifications (allow notifications when prompted)

OPTIONAL FEATURES
- HealthKit: More → Data & Integrations → enable Health sync
- AI Coach: Coach tab (requires network; uses https://the-workout-log.onrender.com)
- Form guides: during active workout, tap exercise → form guide (network optional)

LIVE ACTIVITY
Rest timer Live Activity appears during active workouts on supported devices.

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
