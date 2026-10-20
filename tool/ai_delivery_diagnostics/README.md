# AI Delivery Diagnostics

These tools reproduce the bounded 2026-08-14 AI delivery investigation without using a user's food photo. `controlled_meal_reference_q94.jpg` is a generated 1,448 x 1,086 JPEG containing four labeled edible portions and two non-food scale references. It is 446,757 bytes, close to the historical production Chat image payloads used for comparison.

## Provider Probe

The provider probe compares text and image Planner latency or interleaves the current Food policy with the pre-Phase-5.11 baseline policy.

```powershell
npm.cmd exec --yes deno -- run --allow-read --allow-env --allow-net --env-file=supabase/.env.local tool/ai_delivery_diagnostics/provider_probe.ts --image tool/ai_delivery_diagnostics/controlled_meal_reference_q94.jpg --iterations 5 --suite planner --planner-timeout-ms 8000
```

Use `--suite planner`, `--suite food`, or `--suite all`. The timeout override is diagnostic only and is limited to 1-30 seconds.

## Accepted Delivery Canary

The canary signs in with the existing acceptance account, invokes the deployed asynchronous Add Food route, observes the delivery at the same immediate-plus-three-second cadence as Flutter, reads the service latency breakdown, and deletes the canary delivery/log rows afterward.

```powershell
npm.cmd exec --yes deno -- run --allow-read --allow-env --allow-net tool/ai_delivery_diagnostics/photo_delivery_canary.ts --image tool/ai_delivery_diagnostics/controlled_meal_reference_q94.jpg
```

The canary requires `supabase/.env.local` and `supabase/.env.acceptance.local`. Neither tool prints raw prompts, image bytes, raw Provider output, secrets, account IDs, session IDs, or delivery IDs. Output is limited to durations, bounded status/reason categories, contract validity, item count, total weight, and response size.
