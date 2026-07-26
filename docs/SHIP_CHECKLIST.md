# Ship checklist — Workout Log AI (Phase 1 + 2)

Branch: `feature/phase-1-workout-log-ai` → merge to `main` before / with submission so GitHub Pages (`docs/`) stays aligned.

## 1. Xcode Cloud → TestFlight

- [ ] Xcode Cloud built **`feature/phase-1-workout-log-ai`** successfully  
- [ ] Install **that** TestFlight build on a physical device  
- [ ] Spot-check ([APP_STORE_SMOKE_TEST.md](APP_STORE_SMOKE_TEST.md)): free log + readiness + history clamp + Coach paywall; Premium unlock + Restore; widget  

| Build number | Date | Tester | Pass? |
|--------------|------|--------|-------|
| | | | |

## 2. Merge to `main`

- [x] Feature branch contains Phase 1 freemium + Phase 2 on-device AI  
- [x] Merged `feature/phase-1-workout-log-ai` → `main` (`fdd1a61`)  
- [x] `main` pushed; confirm GitHub Pages redeploys `privacy-policy.html` / `support.html`  

## 3. App Store Connect packaging

Copy from [APP_STORE_METADATA.md](../APP_STORE_METADATA.md) and [APP_STORE_COMPLIANCE.md](APP_STORE_COMPLIANCE.md).

- [ ] App name **Workout Log AI**; subtitle / keywords / description / What’s New  
- [ ] Support URL + Privacy URL live (GitHub Pages `/docs`)  
- [ ] Subscription group attached to this version (first group ships with the version)  
- [ ] ASC products not stuck on Missing Metadata (review screenshot + group localization)  
- [ ] Privacy Nutrition Labels: Purchases + Health (sleep, HRV, RHR)  
- [ ] Screenshots: Home+readiness, paywall, Coach, History, widget  
- [ ] Review notes pasted (see compliance doc § App Review notes)  

## 4. Submit

- [ ] Select the signed-off TestFlight build  
- [ ] Attach IAPs  
- [ ] Submit for Review  

## 5. Post-release (48h)

- [ ] Production purchase → Premium Active → Coach / Adjust unlock  
- [ ] RevenueCat shows **production** transactions  
- [ ] Existing users migrate cleanly (V5→V6)  
- [ ] Crash / feedback watch (esp. non–Apple Intelligence devices)  

## Related

- [PHASE_2_STAGE_A_OPERATOR.md](PHASE_2_STAGE_A_OPERATOR.md)  
- [SUBMISSION_GUIDE.md](SUBMISSION_GUIDE.md)  
- [ON_DEVICE_AI.md](ON_DEVICE_AI.md)  
- [REVENUECAT_SETUP.md](REVENUECAT_SETUP.md)  
