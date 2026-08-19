# App Store Connect – copy & paste

Replace placeholders (`YOUR_EMAIL`, your GitHub username) where noted. **Character limits** are enforced by Apple.

---

## Subtitle (max **30** characters)

**Recommended:**
```
Train smarter. Recover better.
```
*(30 characters)*

**Alternatives (all ≤30):**
- `Strength + readiness coach` (28)
- `Log lifts. Readiness. AI.` (26)
- `Smart workout log & coach` (25)

---

## Keywords (max **100** characters total)

Comma-separated, **no spaces** after commas. Don’t repeat words from your app **name** (“Workout Log AI”)—Apple indexes the name separately.

**Recommended string (99 chars):**
```
gym,fitness,strength,readiness,HRV,sleep,AI,coach,hypertrophy,training,lifting,periodization
```

**Slightly different mix (98 chars):**
```
fitness,gym,strength,training,lifting,logger,exercise,reps,rest,timer,barbell,dumbbell,progress
```

---

## Promotional text (optional, max **170** characters)

Updates anytime without a new binary. Example:
```
Train smarter with readiness scores from Apple Health, home screen widgets, and optional Premium AI coaching—logging stays free.
```

---

## Description (max **4000** characters)

Copy below into App Store Connect → **Description**.

```
Workout Log AI helps you train with intention: log every set, see today's readiness, and upgrade to Premium for AI coaching and deeper analytics.

FREE — ALWAYS
• Log workouts with rest timer and Live Activity
• Plan sessions from templates or build your own
• Today's Readiness Score (training load + optional Apple Health)
• Home screen widget with quick-log shortcut
• Custom exercises and 14-day history

PREMIUM
• AI Coach chat and natural-language program builder
• Readiness trends (7–90 days)
• Advanced analytics, unlimited history, and export

READINESS
Connect Apple Health when you're ready for sleep, HRV, and resting heart rate inputs. Scores are computed on device and are general fitness guidance—not medical advice.

PRIVACY-FIRST
Workouts stay on your iPhone with SwiftData. Sign in with Apple is optional. Subscriptions are managed by Apple; restore anytime in Settings.

Whether you're chasing hypertrophy, strength, or consistency, Workout Log AI keeps logging free and puts smarter coaching one upgrade away.

SUBSCRIPTIONS
Premium is an auto-renewable subscription (monthly and annual) with an optional 14-day free trial. Payment is charged to your Apple ID. Subscriptions renew unless cancelled at least 24 hours before the end of the period. Manage in iOS Settings or More → Subscription.

Privacy Policy: https://cianfrocco4.github.io/FitLog/privacy-policy.html
Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

---

## Support URL

Apple needs a **web page** (not only `mailto:`). Options:

1. **Host `docs/support.html`** the same way as your privacy policy (e.g. GitHub Pages from `/docs`):  
   `https://YOUR_USERNAME.github.io/FitLog/support.html`

2. **GitHub repo** (if you’re okay with it):  
   `https://github.com/cianfrocco4/FitLog` — acceptable as support for many indie apps, but a dedicated support page looks more professional.

**Before publishing:** Edit `docs/support.html` and set your real support email.

---

## Terms of Use (EULA) — required for subscriptions (Guideline 3.1.2(c))

This app uses **Apple’s Standard Licensed Application EULA** (do not upload a custom EULA in App Store Connect unless you wrote one).

Paste this URL into the **App Description** (already included in the Description block above):

```
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
```

**Privacy Policy URL** (App Information):

```
https://cianfrocco4.github.io/FitLog/privacy-policy.html
```

Optional first-party Terms page (GitHub Pages): `https://cianfrocco4.github.io/FitLog/terms-of-use.html` — in-app Terms of Use still opens Apple’s standard EULA.

---

## Marketing URL (optional)

Same as Support, your personal site, or GitHub repo.

---

## What’s new (release notes) – 1.0.1

```
Workout Log AI 1.0.1

• Delete your account from Settings
• More reliable exercise form-guide videos
• Clearer first-run setup and Home tour
• Accessibility and Guided Coach polish
```
