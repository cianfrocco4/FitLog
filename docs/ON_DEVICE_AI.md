# On-device AI (Foundation Models)

Workout Log AI prefers **Apple Foundation Models** (on-device) for Premium coaching when the device supports Apple Intelligence (iOS 26+). Cloud OpenAI via the existing proxy remains the fallback for heavy work and unsupported devices.

## Availability matrix

| Condition | Daily Adjust / Insights / short Coach / form cues | Full program generation |
|---|---|---|
| Premium + Apple Intelligence available | On-device first | Cloud |
| Premium + FM unavailable | Cloud, then heuristic | Cloud |
| Free | Heuristics / paywall | Paywall |

Check at runtime: `AIRoutingService.shared.onDeviceAvailability`.

## Privacy

- On-device prompts use **summarized** readiness + plan context already in the app — not raw HealthKit streams.
- On-device path does not send Health data to a server.
- Cloud fallback uses the existing coach proxy and snapshot rules.
- All AI surfaces show **Not medical advice**.

## Feature entry points

- **Adjust today’s plan** — Home (scheduled workout) → `DailyAdjustSheet`
- **Week in review** — Home `WeeklyInsightCard`
- **Substitutions** — Exercise detail → Suggest substitutes
- **Form cues** — Exercise detail / form guide (router)
- **Coach** — Short single-turn messages may use on-device; longer threads stay cloud streaming

## Analytics

- `on_device_ai_used`
- `on_device_ai_unavailable`
- `ai_routed_cloud_fallback`

## Operator note

Stage A ship closeout (TestFlight / App Review) is documented in [PHASE_2_STAGE_A_OPERATOR.md](PHASE_2_STAGE_A_OPERATOR.md).
