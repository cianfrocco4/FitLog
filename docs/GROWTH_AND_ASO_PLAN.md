# Workout Log AI — Rankings, Acquisition & Ratings Plan

Status as of 28 Aug 2026. The app is **Ready for Sale**. Search is not broken.

| Fact | Value |
| --- | --- |
| Product page | [apps.apple.com/us/app/workout-log-ai/id6759616774](https://apps.apple.com/us/app/workout-log-ai/id6759616774) |
| Released | 19 Aug 2026 (version **1.0** still live) |
| Ratings | **0** — page shows “hasn’t received enough ratings or reviews” |
| Findable today | Direct URL; search **Anthony Cianfrocco**; search **WorkoutLogAI** (~#17) |
| Not findable | `Workout Log AI` — not in the first ~200 US/GB/CA results |
| Pricing | Free + IAP Premium Monthly **$5.99** / Annual **$49.99** |
| Category | Health & Fitness (secondary: Lifestyle) |
| Requirement | iOS 18+ |

Apple’s search is a **popularity-weighted ranker**, not a catalog. A 9-day-old app with a generic three-word name and zero ratings will lose `workout` + `log` + `AI` to Fitbod, Fitness AI, Flex, Syntax, GymLog AI, and even an app named “AI Workout Log.” Description text is **not indexed**. Title, subtitle, keyword field, screenshot captions, and in-app event titles are.

**Order of operations (do not skip ahead):**

1. Make the listing easy to open and rate (this week, mostly outside code).
2. Get the first **5–10 ratings** (unlocks conversion; Apple shows a star summary).
3. Refresh the product page so the people who *do* land convert.
4. Buy your own brand term so the spaced name at least shows you.
5. Only then chase category keywords and communities.

Chasing “workout log” rankings before you have ratings is wasted effort.

---

## Goals and scoreboard

Track these every Monday in App Store Connect → **Analytics** (and RevenueCat for paid). You do **not** have a cloud product-analytics SDK today (`AnalyticsService` is local OSLog only). Use Apple’s numbers; do not add Mixpanel/Adjust unless you also update App Privacy.

| Metric | Where | Week 2 target | Day 45 target |
| --- | --- | --- | --- |
| Ratings (all versions) | Product page / ASC | **5+** | **25+**, ≥4.5★ |
| Product page views | ASC Analytics | Baseline | 3× week-1 |
| Impression → product page | ASC | — | ≥8% |
| Product page → download | ASC | — | ≥25% (screenshots matter) |
| Brand search: `Workout Log AI` | Phone + [iTunes Search API](https://itunes.apple.com/search?term=Workout%20Log%20AI&entity=software&country=us) | Visible in first 2 pages **or** via Search Ads | Organic first page |
| Brand search: `WorkoutLogAI` | Same | Hold / improve on #17 | Top 5 |
| First-week retained openers | ASC / instinct until you have events | — | People who log **3 sessions** |
| Trial / paid starts | RevenueCat | Any | Know monthly vs annual mix |

**North-star for ranking:** downloads × conversion × rating quality × retention. Keywords only decide *which queries you are eligible for*.

---

## Phase 0 — This weekend (no App Review required)

These are the highest-leverage actions you can take before any code ships.

### 0.1 Put the URL everywhere you already talk about the app

Use the canonical link, not “search Workout Log AI”:

```
https://apps.apple.com/us/app/workout-log-ai/id6759616774
```

Also say: *“If search fails, type WorkoutLogAI as one word, or Anthony Cianfrocco.”*

Places to paste it today:

- Support page (`docs/support.html` — already live on GitHub Pages; add a **Download on the App Store** heading)
- GitHub repo README
- Email signature / texts to testers
- Any Slack / Discord / group chats you already use
- Instagram / X / Threads bio

### 0.2 Personal rating ask (fastest path to 5 stars on the page)

Apple hides the rating summary until there are enough ratings. Your listing currently looks untrusted.

Ask **people who already used a real build** (TestFlight alumni, friends who lift, you on a non-developer Apple ID). Script:

> Workout Log AI is live: [link]. If you logged even one session, would you leave a star rating on that page? Search won’t show it — use the link. Honest ratings help more than a 5 if something’s broken — tell me first so I can fix it.

Rules:

- Do **not** offer payment, Premium, or gift cards for a rating (App Store Review Guideline **5.6.1** / **3.2**).
- Do **not** ask people who never opened the app.
- Prefer people who completed a workout. A 1★ from a confused first-run user hurts more than silence.

### 0.3 Confirm storefront + listing quality in ASC

In App Store Connect → Workout Log AI:

1. **Pricing and Availability** — confirm the countries you actually want (at least US). A missing storefront is a common “I can’t find it” cause when traveling.
2. **App Store tab → 1.0** — confirm subtitle, keywords, and screenshots match [APP_STORE_METADATA.md](../APP_STORE_METADATA.md). If keywords were never pasted, the long-tail terms (`periodization`, `readiness`, `HRV`) are not indexed.
3. **Product page preview** — View on App Store from ASC (not from iPhone search).
4. Note whether **1.0.1** is already created. Repo marketing version is 1.0.1; the live store version is still **1.0**. Metadata edits for keywords/screenshots can often go out with the next version.

---

## Phase 1 — Ratings engine (ship in 1.0.1 / 1.0.2)

There is **no** `AppStore.requestReview` / `SKStoreReviewController` in the app today. Simulated “reviews” in `FitLogSimulatedUserReviewer` are internal QA, not App Store ratings. Share on the completion screen does not include the store URL.

### 1.1 In-app review prompt (implement)

Use `StoreKit` `AppStore.requestReview(in:)` (iOS 18+). Apple caps how often the system dialog appears; you cannot force it.

**When to ask (good moments):**

| Trigger | Why |
| --- | --- |
| 3rd completed session (lifetime) | They’ve felt the core loop |
| First PR highlighted on the completion sheet | Peak emotion |
| 7-day readiness streak after Health is connected | Differentiator, not a first-launch nag |

**When never to ask:**

- First launch / onboarding / paywall dismiss / failed purchase / crash recovery
- Immediately after a 1-set accidental session
- More than once per ~120 days in *your* logic (Apple has its own cap on top)

**Implementation sketch:**

- New `@Observable` `AppReviewPromptController` in `Sources/Features/Ratings/` (or `FitLog/Features/Ratings/` to match current layout)
- Persist `completedSessionCountAtLastPrompt` + `lastPromptDate` in `UserPreferences`
- Call from `MainTabView` / completion-summary dismiss path after `firstWorkoutLogged` already fires (`MainTabView` tracks that event today)
- `#Preview` + unit tests for “3rd session yes / 2nd no / too soon no”
- Accessibility: the system dialog is Apple’s; no custom star UI (Guideline 5.6.1 — you may not incentivize or gate features on a rating)

Optional second path (does **not** count on the product page until they submit): a Settings row **Rate Workout Log AI** that opens

```
https://apps.apple.com/app/id6759616774?action=write-review
```

Use this for people who said they would rate but the system dialog never appeared.

### 1.2 Brand the share card (implement)

`WorkoutCompletionSummary.shareLines` and `WorkoutCompletionShareCard` already say `AppBrand.name` but **do not include the store URL**. Every shared PR image is unpaid distribution with no way back.

Add one line to text share and a small footer on the image card:

```
https://apps.apple.com/us/app/workout-log-ai/id6759616774
```

Keep it one tap; do not make share feel like an ad. Files: `FitLog/WorkoutCompletionSummary.swift`, `FitLogTests/WorkoutCompletionSummaryShareTests.swift`.

### 1.3 Soft “how did that session go?” (optional, later)

A two-button sheet (Good / Had issues) after session 5+:

- Good → `requestReview`
- Issues → `mailto:` support (already `acianfrocco@gmail.com` on the support page)

This filters unhappy users away from the public star rating. Do this only after the basic prompt exists.

---

## Phase 2 — Product page that converts (ASC, next version)

People who find you via URL or Search Ads decide in **3 screenshots**. Simulator status-bar shots dated “2026-08-03” look unfinished next to Fitbod.

### 2.1 Screenshot captions (indexed since mid-2025)

Reshoot on a physical device or a clean simulator (hide the time/date chrome if you can). First three iPhone 6.7" frames, in order:

1. **Log a set in seconds** — active workout + rest timer. Caption: `Log sets. Rest timer. Live Activity.`
2. **Today’s readiness** — Home readiness card + Health. Caption: `Readiness from Apple Health. On device.`
3. **AI Coach** — a real coaching reply, not a paywall wall of text. Caption: `Premium AI coach. Programs in plain English.`

Then: History / PRs, home-screen widget, paywall with real prices. Add **text captions on the image** (OCR is a ranking surface). Light *and* dark if you only have time for one extra pass, ship light.

### 2.2 Preview video (30–30s)

Optional but high conversion: 15–30s of tap-to-log → rest timer → completion share. No voiceover required. Upload as App Preview on 6.7".

### 2.3 Title / subtitle / keywords (decision + ASC paste)

**Title (30 chars) — pick one. This is the ranking lever.**

| Option | Chars | Effect |
| --- | --- | --- |
| Keep `Workout Log AI` | 14 | Brand is generic; spaced search stays brutal |
| `FitLog: Workout Log AI` | 22 | Unique token + same keywords; matches repo/bundle mental model |
| `WorkoutLogAI` as visible name | 12 | Matches the query that already works; weaker English readability |

Recommendation: **`FitLog: Workout Log AI`** if you are willing to say “FitLog” in conversation. If not, keep the legal name and put **FitLog** in the subtitle.

**Subtitle (30) — current:** `Train smarter. Recover better.` (brand, not searchable).

Better for indexing (do not repeat title words):

```
FitLog readiness & HRV coach
```

(29) or, if FitLog is already in the title:

```
Readiness, HRV & lift coach
```

(28)

**Keywords (100, no spaces after commas, no words already in title/subtitle):**

```
gym,strength,hypertrophy,periodization,sleep,lifting,barbell,dumbbell,logger,reps,timer,export
```

(98) — drop `AI`, `coach`, `readiness`, `HRV`, `fitness`, `training` if those sit in title/subtitle/category.

Promotional text (editable anytime, **not** indexed — use for the rating ask):

```
Live on the App Store. If search hides us, open the link from Settings or search WorkoutLogAI. Logging stays free.
```

Paste into ASC on the **next** version. Update [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) in the same PR as the screenshots so the repo stays the source of truth.

### 2.4 Localization (only if you will support it)

English (U.S.) only today. Do **not** add UK/AU/CA locales with the same English keywords unless you also upload screenshots — empty locales can dilute. One locale, done well, is enough until you have ratings.

---

## Phase 3 — Paid discovery (small budget, brand first)

### 3.1 Apple Search Ads — exact brand (start here)

Create a campaign in [Apple Search Ads](https://ads.apple.com) for the US storefront:

| Campaign | Match | Daily cap | Goal |
| --- | --- | --- | --- |
| Brand exact | Exact: `Workout Log AI`, `WorkoutLogAI`, `FitLog` | $5–10 | **Appear when someone types your name** |
| Brand CPT | Same terms, CPT bid | Same | Cheaper if exact CPA is high |
| Competitor / category | `workout log`, `hevy`, `strong app` | $0 until 10+ ratings | You will lose on CPA |

This does not “buy organic rank,” but it fixes the exact pain you hit: the name query shows incumbents. After 2 weeks, check Search Match search terms and add negatives (`calorie`, `running only`, `yoga`).

You need the Paid Apps agreement (already required for subscriptions) and Ads account on the same Apple ID.

### 3.2 What not to buy yet

Meta/TikTok/Google UAC, influencer seeding, and ASA category keywords. With 0 ratings, paid users bounce and you pay to lose. Revisit after 25 ratings and a screenshot refresh.

---

## Phase 4 — Organic users (hours, not ads)

You are a privacy-first indie logger with Apple Health readiness and optional on-device AI. Lead with **that**, not “another AI workout app.”

### 4.1 Communities (value-first; no “download my app” cold posts)

| Place | How |
| --- | --- |
| r/weightroom, r/Fitness, r/stronglifts, r/AppleWatch | Answer logging / HRV / periodization questions. Mention the app only when asked or in a weekly “what I use” comment. Read each sub’s self-promo rules. |
| r/iOSProgramming, r/SwiftUI, Indie Hackers, r/SideProject | Ship-story post: local-first SwiftData, no account required, App Store search failed for the exact name. Developers convert and review. |
| Discord / gym group chats you already belong to | Link + “search WorkoutLogAI” |
| X / Threads / Bluesky | 2–3 posts: completion-card screenshot, readiness widget on a Home Screen, “why I built logging free.” Pin the store URL. |

Avoid Product Hunt until you have 5+ ratings and polished screenshots — a dead launch is worse than waiting 2 weeks.

### 4.2 Content that compounds

One artifact per week, reused:

1. “How readiness is scored on device (not medical advice)” — blog on GitHub Pages or a note.
2. Short screen recording of log → rest timer → Live Activity.
3. Comparison table you can honestly win: **no account required**, Health on-device, widgets, 14-day history free.

Do not claim medical HRV diagnosis. Keep the existing “general fitness guidance” language.

### 4.3 Widget as a billboard

The readiness / quick-log widget is free advertising on the Home Screen. In onboarding or the spotlight tour, add one clear **Add widget** moment after the first logged session — not during welcome. Files: `OnboardingFlowView.swift`, `SpotlightOverlay.swift`, widget target.

### 4.4 TestFlight → production bridge

Anyone still on TestFlight should get a note: production is live, please install from the store and rate there. TestFlight stars do **not** count on the public page.

---

## Phase 5 — Product changes that create ranking signals

These improve retention (a ranking input) and give people something to share.

| Change | Why it grows users | Effort |
| --- | --- | --- |
| Review prompt + write-review link (§1.1) | Ratings | S |
| Store URL on share card (§1.2) | Viral loop | S |
| Distinctive title / subtitle (§2.3) | Eligibility for brand + long-tail | S (ASC) |
| Screenshot captions (§2.1) | Conversion + OCR keywords | M |
| Post-3rd-workout “Add widget” | Daily opens | S |
| In-app event (e.g. “First-week training”) | Extra indexed title (30 chars) | S in ASC |
| Cloud analytics sink behind `AnalyticsSink` | See funnel; update App Privacy first | M |
| English UK / DE / ES metadata | More storefronts | L (don’t start) |
| Referral / credits for invites | Risky vs 3.1.1; skip | — |

Do **not** add a custom “rate 5 stars for Premium” flow. Do **not** add ATT/ad SDKs just to grow — it fights the privacy story and the current nutrition labels.

---

## Week-by-week (you + optional engineering)

### Week 1 — Findable + first ratings

- [ ] Paste store URL on support page, README, bios
- [ ] Text 10 people who actually trained in the app
- [ ] Confirm ASC availability + keywords actually saved
- [ ] Create ASA brand campaign at $5–10/day
- [ ] Decide title: keep vs `FitLog: Workout Log AI`
- [ ] Engineering: review prompt + share URL (this repo)

### Weeks 2–3 — Listing refresh with 1.0.1

- [ ] New screenshots + captions
- [ ] Subtitle + keyword string from §2.3
- [ ] Submit 1.0.1 (account deletion / form-guide already in What’s New)
- [ ] Soft-launch posts in developer communities
- [ ] Recheck `Workout Log AI` search on a friend’s phone (not yourdeveloper device only)

### Weeks 4–6 — Habit + proof

- [ ] Widget CTA after first sessions
- [ ] One honest “how I built this” post
- [ ] Reply to every App Store review (automation exists: [ASC_REVIEW_INTAKE.md](ASC_REVIEW_INTAKE.md))
- [ ] ASA search-term report; add negatives
- [ ] If ≥10 ratings and conversion ≥25%, consider *one* category exact match (`readiness score`, not `workout log`)

### After you have 25 ratings

Re-run the iTunes search check. If brand exact still fails, the title change is the remaining lever. Only then spend on category Search Ads or a Product Hunt day.

---

## Engineering backlog (when you want implementation)

Numbered for Agent mode. No schema / SwiftData migration.

1. **Ratings** — `AppReviewPromptController` + `UserPreferences` gates; hook after workout complete; Settings write-review link; tests.
2. **Share attribution** — append store URL in `shareLines` and share-card footer; update `WorkoutCompletionSummaryShareTests`.
3. **Support / README** — App Store badge + URL + “search WorkoutLogAI”.
4. **Metadata source of truth** — refresh `APP_STORE_METADATA.md` once you pick a title/subtitle.
5. **Widget CTA** — one-time Home banner after session 1–2.
6. **Optional** — wire `AnalyticsSink` to RevenueCat dashboard events only (already have paywall events); no new privacy types if it stays RC.

---

## What success looks like vs what will not happen

**Will happen if you execute Phases 0–2:** the product page looks trusted, friends can rate, Search Ads + `WorkoutLogAI` cover name search, share images send people to the store.

**Will not happen in 30 days:** organic #1 for `workout log` or `AI workout`. Those terms are owned by funded apps. You win **brand** and **long-tail** (readiness, on-device, periodization, no account) first.

**Verify ranking anytime:**

```bash
curl -sS "https://itunes.apple.com/search?term=Workout%20Log%20AI&entity=software&country=us&limit=200" \
  | python3 -c "import json,sys; d=json.load(sys.stdin);
print(next((i+1 for i,r in enumerate(d['results']) if r.get('trackId')==6759616774), 'not in top %d'%len(d['results'])))"
```

Also try `term=WorkoutLogAI` and `term=Anthony%20Cianfrocco`.
